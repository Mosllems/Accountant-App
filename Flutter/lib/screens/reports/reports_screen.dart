import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/calendar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/payment_row.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/worker_picker.dart';
import '../../models/worker.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';
import '../common/snapshot_view.dart';
import '../payments/payment_details_dialog.dart';
import 'report_charts.dart';

/// Reports tab. All figures are display-only aggregates of backend values
/// over the complete (unpaginated) dataset; definitions are labelled.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  YearMonth _month = YearMonth.current();
  int? _workerId;

  static const _chartMonths = 6;

  List<YearMonth> get _window {
    final list = <YearMonth>[_month];
    while (list.length < _chartMonths) {
      list.insert(0, list.first.previous);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SnapshotView(
        skeleton: const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: SkeletonList(count: 4, rowHeight: 140),
        ),
        builder: (context, data) {
          final accounts = data.accountsIn(_month);
          int count(AccountStatus s) =>
              accounts.where((wa) => wa.account.status == s).length;

          final window = _window;
          final paidByDate = [
            for (final m in window)
              MonthValues(m, [
                data
                    .paymentsDatedIn(m)
                    .fold<num>(0, (s, e) => s + e.payment.amount),
              ]),
          ];
          final salaryVsPaid = [
            for (final m in window)
              MonthValues(m, [
                data
                    .accountsIn(m)
                    .fold<num>(0, (s, wa) => s + wa.account.calculatedAmount),
                data
                    .accountsIn(m)
                    .fold<num>(0, (s, wa) => s + wa.account.totalPayments),
              ]),
          ];
          bool allZero(List<MonthValues> l) =>
              l.every((d) => d.values.every((v) => v == 0));

          return RefreshIndicator(
            onRefresh: AppScope.of(context).refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PageHeader(title: 'گزارش‌ها'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MonthSelector(
                              value: _month,
                              onChanged: (m) => setState(() => _month = m),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            // Per-worker report first (owner request),
                            // then the month totals and charts.
                            _WorkerReport(
                              data: data,
                              month: _month,
                              workerId: _workerId,
                              onWorker: (id) => setState(() => _workerId = id),
                            ),
                            const SizedBox(height: AppSpacing.sectionGap),
                            if (accounts.isEmpty)
                              AppCard(
                                child: EmptyState(
                                  compact: true,
                                  icon: Icons.event_busy_outlined,
                                  title:
                                      'داده‌ای برای ${_month.label} موجود نیست',
                                  message: 'هیچ حساب ماهانه‌ای برای این ماه ثبت نشده است.',
                                ),
                              )
                            else ...[
                              AppCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SectionTitle('وضعیت حساب کارگران'),
                                    for (final s in [
                                      AccountStatus.debtor,
                                      AccountStatus.creditor,
                                      AccountStatus.paid,
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.xs,
                                        ),
                                        child: Row(
                                          children: [
                                            StatusBadge(status: s),
                                            const Spacer(),
                                            Text(
                                              '${formatCount(count(s))} کارگر',
                                              style: AppText.bodyStrong,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sectionGap),
                            _ChartCard(
                              title: 'پرداخت‌ها بر اساس تاریخ پرداخت',
                              subtitle:
                                  '${formatCount(_chartMonths)} ماه منتهی به ${_month.label}',
                              empty: allZero(paidByDate),
                              child: MonthlyBarChart(
                                data: paidByDate,
                                seriesLabels: const ['پرداخت‌ها'],
                                semanticsSummary: _summary(paidByDate, const [
                                  'پرداخت',
                                ]),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.cardGap),
                            _ChartCard(
                              title: 'حقوق در برابر پرداخت',
                              subtitle: 'بر اساس ماه حساب (حقوق محاسبه‌شده و پرداخت‌های همان حساب)',
                              empty: allZero(salaryVsPaid),
                              child: MonthlyBarChart(
                                data: salaryVsPaid,
                                seriesLabels: const [
                                  'حقوق محاسبه‌شده',
                                  'پرداخت‌ها',
                                ],
                                semanticsSummary: _summary(salaryVsPaid, const [
                                  'حقوق',
                                  'پرداخت',
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _summary(List<MonthValues> data, List<String> names) => data
      .map(
        (d) =>
            '${d.month.label}: ${[for (var i = 0; i < d.values.length; i++) '${names[i]} ${formatMoney(d.values[i])}'].join('، ')}',
      )
      .join('. ');
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.empty,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool empty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.cardTitle),
          Text(subtitle, style: AppText.secondary),
          const SizedBox(height: AppSpacing.lg),
          if (empty)
            const EmptyState(
              compact: true,
              icon: Icons.bar_chart_outlined,
              title: 'داده‌ای برای این بازه موجود نیست',
            )
          else
            child,
        ],
      ),
    );
  }
}

class _WorkerReport extends StatelessWidget {
  const _WorkerReport({
    required this.data,
    required this.month,
    required this.workerId,
    required this.onWorker,
  });

  final PayrollSnapshot data;
  final YearMonth month;
  final int? workerId;
  final ValueChanged<int?> onWorker;

  @override
  Widget build(BuildContext context) {
    final worker = workerId == null ? null : data.workerById(workerId!);
    final account = worker?.accountFor(month);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('گزارش کارگران'),
          WorkerSelectField(
            workers: data.workers,
            selected: worker,
            onChanged: (w) => onWorker(w?.id),
          ),
          const SizedBox(height: AppSpacing.md),
          if (worker == null)
            _AllWorkers(
              accounts: data.accountsIn(month),
              month: month,
              onSelect: onWorker,
            )
          else if (account == null)
            EmptyState(
              compact: true,
              icon: Icons.event_busy_outlined,
              title: 'برای ${worker.name} در ${month.label} حسابی ثبت نشده است',
            )
          else ...[
            Row(
              children: [
                Expanded(child: Text(month.label, style: AppText.bodyStrong)),
                StatusBadge(status: account.status, label: account.statusLabel),
              ],
            ),
            InfoRow(
              label: 'حقوق پایه',
              value: formatMoney(account.monthlySalary?.salary),
            ),
            InfoRow(
              label: 'حقوق محاسبه‌شده',
              value: formatMoney(account.calculatedAmount),
            ),
            InfoRow(
              label: 'مجموع پرداخت‌ها',
              value: formatMoney(account.totalPayments),
            ),
            InfoRow(
              label: 'مانده',
              value: formatMoneyAbs(account.balance),
              emphasize: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (account.payments.isEmpty)
              const Text(
                'پرداختی برای این ماه ثبت نشده است.',
                style: AppText.secondary,
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                child: Column(
                  children: [
                    for (final p in [
                      ...account.payments,
                    ]..sort((a, b) => b.compareByDate(a)))
                      Builder(
                        builder: (context) {
                          final entry = PaymentEntry(
                            payment: p,
                            worker: worker,
                            account: account,
                          );
                          return PaymentRow(
                            entry: entry,
                            showWorker: false,
                            onTap: () =>
                                showPaymentDetailsDialog(context, entry),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// «همه‌ی کارگران»: each worker's account for the month; tap → that worker.
class _AllWorkers extends StatelessWidget {
  const _AllWorkers({
    required this.accounts,
    required this.month,
    required this.onSelect,
  });

  final List<WorkerAccount> accounts;
  final YearMonth month;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return EmptyState(
        compact: true,
        icon: Icons.event_busy_outlined,
        title: 'برای ${month.label} حسابی ثبت نشده است',
      );
    }
    final sorted = [...accounts]
      ..sort((a, b) => a.worker.name.compareTo(b.worker.name));
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const Divider(),
            InkWell(
              onTap: () => onSelect(sorted[i].worker.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sorted[i].worker.name,
                            style: AppText.bodyStrong,
                          ),
                          Text(
                            'مانده: ${formatMoneyAbs(sorted[i].account.balance)}',
                            style: AppText.secondary,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      status: sorted[i].account.status,
                      label: sorted[i].account.statusLabel,
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
