import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'screens/shell/app_shell.dart';
import 'services/app_scope.dart';
import 'services/payroll_repository.dart';

void main() {
  runApp(PayrollApp(repository: PayrollRepository()));
}

class PayrollApp extends StatelessWidget {
  const PayrollApp({super.key, required this.repository});

  final PayrollRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: repository,
      child: MaterialApp(
        title: 'جهان سنگ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AppShell(),
      ),
    );
  }
}
