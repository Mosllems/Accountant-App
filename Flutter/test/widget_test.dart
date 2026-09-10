// تست ساده برای اطمینان از اینکه اپ بدون خطا ساخته می‌شود.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App builds and shows worker list screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PayrollApp());

    // عنوان صفحه اصلی باید نمایش داده شود
    expect(find.text('کارگران'), findsOneWidget);

    // جهت متن باید راست‌به‌چپ باشد
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
  });
}
