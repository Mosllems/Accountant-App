import 'package:flutter/widgets.dart';

import 'payroll_repository.dart';

/// Provides the [PayrollRepository] to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.repository, required super.child});

  final PayrollRepository repository;

  static PayrollRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repository != oldWidget.repository;
}
