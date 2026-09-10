import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:http/http.dart' as http;

/// خطای سطح اپلیکیشن برای نمایش به کاربر.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// کلاینت ارتباط با API بک‌اند جنگو.
class ApiClient {
  // آدرس بک‌اند: هوشمند تشخیص می‌دهد.
  // - وب (Chrome): http://127.0.0.1:8000
  // - امولاتور اندروید: http://10.0.2.2:8000  (10.0.2.2 = کامپیوتر میزبان)
  // - دستگاه فیزیکی یا ویندوز: http://127.0.0.1:8000
  // همچنین می‌توانید با --dart-define=API_BASE_URL=... دستی تنظیم کنید.
  static final String baseUrl = const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  /// گرفتن لیست کارگرها.
  Future<List<dynamic>> getWorkers() async {
    final response = await _get('/api/workers/');
    // DRF ممکن است لیست خام برگرداند یا آبجکت صفحه‌بندی‌شده با کلید results
    if (response is List) return response;
    if (response is Map && response['results'] is List) {
      return response['results'] as List;
    }
    throw ApiException('ساختار پاسخ لیست کارگرها نامعتبر است');
  }

  /// گرفتن جزئیات یک کارگر.
  Future<Map<String, dynamic>> getWorkerDetail(int id) async {
    final response = await _get('/api/workers/$id/');
    if (response is Map<String, dynamic>) return response;
    throw ApiException('ساختار پاسخ جزئیات کارگر نامعتبر است');
  }

  Future<dynamic> _get(String path) async {
    try {
      final response = await _client
          .get(
            _uri(path),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw ApiException(
          'خطای سرور (${response.statusCode}) در دریافت $path',
        );
      }

      return jsonDecode(utf8.decode(response.bodyBytes));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'اتصال به سرور برقرار نشد.\n'
        'آدرس: $baseUrl\n'
        'مطمئن شوید سرور جنگو در حال اجراست.\n\n$e',
      );
    }
  }
}
