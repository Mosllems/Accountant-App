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

  group('paginated lists', () {
    http.Response page(List<int> ids, int count, String? next) =>
        http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'count': count,
              'next': next,
              'previous': null,
              'results': [
                for (final id in ids) {'id': id},
              ],
            }),
          ),
          200,
        );

    test('follows next through all pages, always via baseUrl', () async {
      final requested = <Uri>[];
      final api = ApiClient(
        client: MockClient((req) async {
          requested.add(req.url);
          return req.url.queryParameters['page'] == '2'
              ? page([3], 3, null)
              : page([1, 2], 3, 'http://other-host:9999/api/workers/?page=2');
        }),
      );

      final workers = await api.getWorkers();

      expect(workers.map((w) => w['id']), [1, 2, 3]);
      expect(requested, hasLength(2));
      expect(
        requested.last.toString(),
        '${ApiClient.baseUrl}/api/workers/?page=2',
      );
    });

    test(
      'a failing later page fails the whole list (no partial data)',
      () async {
        final api = ApiClient(
          client: MockClient(
            (req) async => req.url.queryParameters['page'] == '2'
                ? http.Response('', 500)
                : page([1], 2, 'http://h/api/workers/?page=2'),
          ),
        );
        await expectLater(
          api.getWorkers(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.server,
            ),
          ),
        );
      },
    );

    test('count mismatch → invalid response', () async {
      final api = ApiClient(
        client: MockClient((_) async => page([1], 5, null)),
      );
      await expectLater(
        api.getWorkers(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
    });

    test('plain unpaginated array still works', () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {'id': 7},
              ]),
            ),
            200,
          ),
        ),
      );
      expect((await api.getWorkers()).single['id'], 7);
    });
  });
}
