import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/format/jalali.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_application_1/services/payroll_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Test fixture shaped exactly like the DRF responses (current month, so
/// the dashboard has data).
Map<String, dynamic> _workerDetail() {
  final now = YearMonth.current();
  final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-05';
  return {
    'id': 1,
    'name': 'علی رضایی',
    'start_date': '1400-01-01',
    'is_active': true,
    'monthly_accounts': [
      {
        'id': 10,
        'monthly_salary': {
          'id': 100,
          'year': now.year,
          'month': now.month,
          'salary': '30000000',
        },
        'eligible_days': 30,
        'daily_salary': '1000000',
        'calculated_amount': '30000000',
        'total_payments': '5000000',
        // Deliberately inconsistent sign vs. status: the UI must show the
        // backend status, never infer it from the balance.
        'balance': '25000000',
        'status': 'debtor',
        'status_display': 'بدهکار',
        'settled_at': null,
        'payments': [
          {
            'id': 7,
            'amount': '5000000',
            'date': date,
            'description': 'علی‌الحساب',
          },
        ],
      },
    ],
  };
}

PayrollRepository _repo({int statusCode = 200}) {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (statusCode != 200) return http.Response('', statusCode);
    if (path == '/api/workers/') {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode([
            {
              'id': 1,
              'name': 'علی رضایی',
              'start_date': '1400-01-01',
              'is_active': true,
            },
          ]),
        ),
        200,
      );
    }
    if (path == '/api/workers/1/') {
      return http.Response.bytes(utf8.encode(jsonEncode(_workerDetail())), 200);
    }
    return http.Response('', 404);
  });
  return PayrollRepository(api: ApiClient(client: client));
}

Future<void> _pumpApp(WidgetTester tester, PayrollRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PayrollApp(repository: repo));
  await tester.pumpAndSettle();
}

/// Scrolls [finder] to the middle of the viewport, then taps it.
Future<void> _tapCentered(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'x',
      packageName: 'x',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('app is RTL with the five tabs in order', (tester) async {
    await _pumpApp(tester, _repo());

    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.rtl,
    );
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['خانه', 'کارگران', 'پرداخت‌ها', 'گزارش‌ها', 'تنظیمات']);
  });

  testWidgets('dashboard shows real data in Persian format', (tester) async {
    await _pumpApp(tester, _repo());

    expect(find.text('ثبت پرداخت جدید'), findsOneWidget);
    expect(
      find.text('مجموع پرداخت‌ها در ${YearMonth.current().label}'),
      findsOneWidget,
    );
    expect(find.text('۵٬۰۰۰٬۰۰۰ تومان'), findsWidgets);
    expect(find.text('علی رضایی'), findsWidgets);
  });

  testWidgets('dashboard add-worker icon opens the add worker form', (
    tester,
  ) async {
    await _pumpApp(tester, _repo());
    expect(find.text('دسترسی سریع'), findsNothing);
    await tester.tap(find.byTooltip('افزودن کارگر'));
    await tester.pumpAndSettle();
    expect(find.text('نام کارگر'), findsOneWidget);
  });

  testWidgets('reports: searchable worker picker with «all workers»', (
    tester,
  ) async {
    await _pumpApp(tester, _repo());
    await tester.tap(find.text('گزارش‌ها').last);
    await tester.pumpAndSettle();

    // «All workers» view lists each worker for the month.
    expect(find.text('همه‌ی کارگران'), findsOneWidget);
    expect(find.text('علی رضایی'), findsOneWidget);

    // Open the picker, search, pick the worker.
    await tester.tap(find.text('همه‌ی کارگران'));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب کارگر'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'علي'); // Arabic ي
    await tester.tap(find.widgetWithText(FilledButton, 'جستجو'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('علی رضایی').last);
    await tester.pumpAndSettle();
    expect(find.text('حقوق پایه'), findsOneWidget);

    // × returns to all workers.
    await tester.tap(find.byTooltip('نمایش همه‌ی کارگران'));
    await tester.pumpAndSettle();
    expect(find.text('حقوق پایه'), findsNothing);
    expect(find.text('همه‌ی کارگران'), findsOneWidget);
  });

  testWidgets('worker status comes from backend, not balance sign', (
    tester,
  ) async {
    await _pumpApp(tester, _repo());
    await tester.tap(find.text('کارگران').last);
    await tester.pumpAndSettle();

    // Balance is positive, backend says debtor → must show «بدهکار».
    expect(find.text('بدهکار'), findsWidgets);
    expect(find.text('طلبکار'), findsOneWidget); // only the filter chip
  });

  testWidgets('payment row opens a read-only details dialog', (tester) async {
    await _pumpApp(tester, _repo());
    await tester.tap(find.text('پرداخت‌ها').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('علی رضایی').first);
    await tester.pumpAndSettle();
    expect(find.text('جزئیات پرداخت'), findsOneWidget);
    expect(find.text('علی‌الحساب'), findsOneWidget);
    await tester.tap(find.text('بستن'));
    await tester.pumpAndSettle();
    expect(find.text('جزئیات پرداخت'), findsNothing);
  });

  testWidgets('register payment: validation, preview, demo mode keeps input', (
    tester,
  ) async {
    await _pumpApp(tester, _repo());
    await tester.tap(find.text('ثبت پرداخت جدید'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('علی رضایی'));
    await tester.pumpAndSettle();

    // Demo-mode banner is visible (BACKEND-GAP(payment-create)).
    expect(find.textContaining('حالت آزمایشی'), findsOneWidget);

    // Empty submit → validation error.
    await _tapCentered(tester, find.widgetWithText(FilledButton, 'ثبت پرداخت'));
    await tester.pumpAndSettle();
    expect(find.text('مبلغ را وارد کنید.'), findsOneWidget);

    // Persian digits are accepted and formatted; preview updates.
    await tester.enterText(find.byType(TextFormField).first, '۲۵۰۰۰۰۰');
    await tester.pumpAndSettle();
    expect(find.text('۲٬۵۰۰٬۰۰۰'), findsOneWidget);
    expect(find.text('۲٬۵۰۰٬۰۰۰ تومان'), findsOneWidget);

    await _tapCentered(tester, find.widgetWithText(FilledButton, 'ثبت پرداخت'));
    await tester.pump(const Duration(milliseconds: 100));
    // In flight: button shows a spinner and is disabled.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();

    // No success claim; still on the form with the input preserved.
    expect(find.text('پرداخت با موفقیت ثبت شد.'), findsNothing);
    expect(
      find.text('حالت آزمایشی: پرداخت در سرور ذخیره نشد.'),
      findsOneWidget,
    );
    expect(find.text('۲٬۵۰۰٬۰۰۰'), findsOneWidget);
  });

  testWidgets('server error shows Persian message with retry', (tester) async {
    await _pumpApp(tester, _repo(statusCode: 500));
    expect(find.text('تلاش مجدد'), findsWidgets);
    expect(find.textContaining('خطایی در سرور رخ داد'), findsWidgets);
    expect(find.textContaining('http'), findsNothing);
  });
}
