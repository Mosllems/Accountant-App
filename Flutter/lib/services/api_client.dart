import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:http/http.dart' as http;

/// Kind of failure, used to choose the Persian message and the UI reaction.
enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  invalidResponse,
}

/// App-level API error. [message] is always a safe Persian text — it never
/// contains URLs, stack traces or raw server output.
class ApiException implements Exception {
  ApiException(this.kind, this.message, {this.fieldErrors = const {}});

  final ApiErrorKind kind;
  final String message;

  /// DRF field validation messages (`{field: [msg]}`), when provided.
  final Map<String, List<String>> fieldErrors;

  /// For writes: the request may have reached the server (e.g. timeout
  /// after sending). The result is unknown — never retry automatically.
  bool get isAmbiguous => kind == ApiErrorKind.timeout;

  @override
  String toString() => message;
}

/// HTTP client for the Django backend.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  // Backend address:
  // - Web (Chrome): http://127.0.0.1:8000
  // - Android emulator: http://10.0.2.2:8000  (host machine)
  // - Override with --dart-define=API_BASE_URL=... (use HTTPS in production).
  static final String baseUrl =
      const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static const _headers = {'Accept': 'application/json'};

  // ---------------------------------------------------------------- workers

  /// `GET /api/workers/`
  Future<List<Map<String, dynamic>>> getWorkers() async =>
      _asList(await _send('GET', '/api/workers/'));

  /// `GET /api/workers/{id}/` (includes monthly_accounts + payments).
  Future<Map<String, dynamic>> getWorkerDetail(int id) async =>
      _asMap(await _send('GET', '/api/workers/$id/'));

  /// `POST /api/workers/` — requires a staff user on the backend.
  Future<Map<String, dynamic>> createWorker({
    required String name,
    required String startDate,
    required bool isActive,
  }) async => _asMap(
    await _send('POST', '/api/workers/', {
      'name': name,
      'start_date': startDate,
      'is_active': isActive,
    }),
  );

  /// `DELETE /api/workers/{id}/` — CASCADE deletes the worker's financial
  /// records on the backend. Requires a staff user.
  Future<void> deleteWorker(int id) async {
    await _send('DELETE', '/api/workers/$id/');
  }

  // --------------------------------------------------------------- payments

  /// `POST /api/payments/` with the body the backend should accept.
  /// NOTE: currently blocked by BACKEND-GAP(payment-create) — see
  /// `data/placeholder/payment_create_placeholder.dart`.
  Future<Map<String, dynamic>> createPayment({
    required int monthlyAccountId,
    required String amount,
    required String date,
    String? description,
  }) async => _asMap(
    await _send('POST', '/api/payments/', {
      'monthly_account': monthlyAccountId,
      'amount': amount,
      'date': date,
      'description': description,
    }),
  );

  // ---------------------------------------------------------------- helpers

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final http.Response response;
    try {
      final request = http.Request(method, _uri(path))
        ..headers.addAll(_headers);
      if (body != null) {
        // Only requests with a body declare JSON (avoids CORS preflight on GET).
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.bodyBytes = utf8.encode(jsonEncode(body));
      }
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        ApiErrorKind.timeout,
        'پاسخی از سرور دریافت نشد. اتصال را بررسی کنید.',
      );
    } on http.ClientException {
      throw _networkError();
    }

    final code = response.statusCode;
    final decoded = _tryDecode(response);
    if (code >= 200 && code < 300) return decoded;
    throw _errorFor(code, decoded);
  }

  ApiException _networkError() => ApiException(
    ApiErrorKind.network,
    'اتصال به سرور برقرار نشد. از روشن بودن سرور و اتصال اینترنت مطمئن شوید.',
  );

  dynamic _tryDecode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }

  ApiException _errorFor(int code, dynamic body) {
    switch (code) {
      case 401:
        return ApiException(
          ApiErrorKind.unauthorized,
          'سرور اجازه‌ی انجام این کار را نمی‌دهد.',
        );
      case 403:
        return ApiException(
          ApiErrorKind.forbidden,
          'اجازه‌ی انجام این کار را ندارید.',
        );
      case 404:
        return ApiException(ApiErrorKind.notFound, 'مورد درخواستی یافت نشد.');
    }
    if (code >= 400 && code < 500) {
      final fields = <String, List<String>>{};
      if (body is Map) {
        body.forEach((key, value) {
          if (value is List) {
            fields['$key'] = value.map((e) => '$e').toList();
          } else if (value is String) {
            fields['$key'] = [value];
          }
        });
      }
      return ApiException(
        ApiErrorKind.validation,
        'اطلاعات واردشده توسط سرور پذیرفته نشد.',
        fieldErrors: fields,
      );
    }
    return ApiException(
      ApiErrorKind.server,
      'خطایی در سرور رخ داد. لطفاً دوباره تلاش کنید.',
    );
  }

  List<Map<String, dynamic>> _asList(dynamic response) {
    // DRF may return a plain list or a paginated {results: [...]} object.
    final list = response is List
        ? response
        : (response is Map && response['results'] is List)
        ? response['results'] as List
        : null;
    if (list == null) throw _invalid();
    return list.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    throw _invalid();
  }

  ApiException _invalid() =>
      ApiException(ApiErrorKind.invalidResponse, 'پاسخ سرور قابل خواندن نبود.');
}
