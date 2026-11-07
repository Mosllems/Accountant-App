import 'dart:convert';

import 'package:flutter_application_1/core/format/jalali.dart';
import 'package:flutter_application_1/core/format/money.dart';
import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'payment body: plain integer amount and Jalali YYYY-MM-DD date',
    () async {
      Map<String, dynamic>? sent;
      final api = ApiClient(
        client: MockClient((req) async {
          sent = jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;
          return http.Response.bytes(utf8.encode(jsonEncode({'id': 1})), 201);
        }),
      );

      await api.createPayment(
        monthlyAccountId: 10,
        amount: normalizeAmountInput('۵٬۰۰۰٬۰۰۰')!,
        date: toApiDate(Jalali(1405, 8, 8)),
        description: 'تست',
      );

      expect(sent, {
        'monthly_account': 10,
        'amount': '5000000',
        'date': '1405-08-08',
        'description': 'تست',
      });
    },
  );

  test('errors map to safe Persian messages and field errors', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'amount': ['نامعتبر'],
            }),
          ),
          400,
        ),
      ),
    );
    await expectLater(
      api.getWorkers(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.fieldErrors['amount'], 'field', ['نامعتبر'])
            .having((e) => e.message.contains('http'), 'no url', isFalse),
      ),
    );
  });

  test('403 → forbidden message', () async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('', 403)),
    );
    await expectLater(
      api.deleteWorker(1),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.forbidden,
        ),
      ),
    );
  });

  test('network failure → network error, not ambiguous', () async {
    final api = ApiClient(
      client: MockClient((_) async => throw http.ClientException('down')),
    );
    await expectLater(
      api.getWorkers(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.network)
            .having((e) => e.isAmbiguous, 'ambiguous', isFalse),
      ),
    );
  });
}
