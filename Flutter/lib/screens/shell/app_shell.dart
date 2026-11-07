import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../dashboard/dashboard_screen.dart';
import '../payments/payments_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../workers/workers_screen.dart';

/// Primary sections, in the required order.
enum AppTab { home, workers, payments, reports, settings }

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = {
  AppTab.home: _Destination('خانه', Icons.home_outlined, Icons.home_rounded),
  AppTab.workers: _Destination(
    'کارگران',
    Icons.people_outline,
    Icons.people_rounded,
  ),
  AppTab.payments: _Destination(
    'پرداخت‌ها',
    Icons.payments_outlined,
    Icons.payments_rounded,
  ),
  AppTab.reports: _Destination(
    'گزارش‌ها',
    Icons.bar_chart_outlined,
    Icons.bar_chart_rounded,
  ),
  AppTab.settings: _Destination(
    'تنظیمات',
    Icons.settings_outlined,
    Icons.settings_rounded,
  ),
};

/// Lets any screen switch the active tab (e.g. dashboard shortcuts).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.goTo, required super.child});

  final ValueChanged<AppTab> goTo;

  static ValueChanged<AppTab> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>()!.goTo;

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// App shell: bottom navigation on phones, navigation rail on wide screens.
/// Tabs keep their state (IndexedStack).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.home;

  static const _pages = [
    DashboardScreen(),
    WorkersScreen(),
    PaymentsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  void _goTo(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = ShellScope(
      goTo: _goTo,
      child: IndexedStack(index: _tab.index, children: _pages),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab.index,
              onDestinationSelected: (i) => _goTo(AppTab.values[i]),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('جهان سنگ', style: AppText.cardTitle),
              ),
              destinations: [
                for (final tab in AppTab.values)
                  NavigationRailDestination(
                    icon: Icon(_destinations[tab]!.icon),
                    selectedIcon: Icon(_destinations[tab]!.selectedIcon),
                    label: Text(_destinations[tab]!.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => _goTo(AppTab.values[i]),
          destinations: [
            for (final tab in AppTab.values)
              NavigationDestination(
                icon: Icon(_destinations[tab]!.icon),
                selectedIcon: Icon(_destinations[tab]!.selectedIcon),
                label: _destinations[tab]!.label,
              ),
          ],
        ),
      ),
    );
  }
}
