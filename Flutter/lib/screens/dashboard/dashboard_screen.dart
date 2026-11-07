import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/payment_row.dart';
import '../../core/widgets/state_views.dart';
import '../../models/worker.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';
import '../common/snapshot_view.dart';
import '../payments/payment_details_dialog.dart';
import '../payments/payment_flow.dart';
import '../shell/app_shell.dart';
import '../workers/add_worker_screen.dart';

/// Home dashboard: current-month overview from real backend data.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SnapshotView(
        skeleton: const _DashboardSkeleton(),
        builder: (context, data) => RefreshIndicator(
          onRefresh: AppScope.of(context).refresh,
          child: _DashboardBody(data: data),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final PayrollSnapshot data;

  @override
  Widget build(BuildContext context) {
    final month = YearMonth.current();
    final monthAccounts = data.accountsIn(month);

    // Display-only aggregates over the complete (unpaginated) dataset.
    final paidInMonth = data
        .paymentsDatedIn(month)
        .fold<num>(0, (sum, e) => sum + e.payment.amount);
    final accruedSalary = monthAccounts.fold<num>(
      0,
      (sum, wa) => sum + wa.account.calculatedAmount,
    );
    int countOf(AccountStatus s) =>
        monthAccounts.where((wa) => wa.account.status == s).length;
    final recent = data.payments.take(5).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App name at the start (right), today's date at the end (left).
              PageHeader(
                title: 'جهان سنگ',
                action: Text(
                  'امروز ${formatDateLong(Jalali.now())}',
                  style: AppText.secondary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DarkSummaryCard(
                      title: 'مجموع پرداخت‌ها در ${month.label}',
                      amount: formatMoney(paidInMonth),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                    PrimaryButton(
                      label: 'ثبت پرداخت جدید',
                      icon: Icons.add_card_outlined,
                      expand: true,
                      onPressed: () => startPaymentFlow(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _TwoColumns(
                      first: StatCard(
                        label: 'تعداد کارگران',
                        value: formatCount(data.activeWorkers.length),
                        icon: Icons.people_outline,
                        caption:
                            'فعال از ${formatCount(data.workers.length)} کارگر',
                        // Same icon as the workers page «افزودن کارگر».
                        action: IconButton.filledTonal(
                          tooltip: 'افزودن کارگر',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.accentSoft,
                            foregroundColor: AppColors.accent,
                            // Rounded rectangle, same language as cards/buttons.
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_outlined),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AddWorkerScreen(),
                            ),
                          ),
                        ),
                      ),
                      second: StatCard(
                        label: 'مجموع حقوق ${monthName(month.month)}',
                        value: monthAccounts.isEmpty
                            ? missingValue
                            : formatMoney(accruedSalary),
                        icon: Icons.request_quote_outlined,
                        caption: monthAccounts.isEmpty
                            ? 'حسابی برای این ماه ثبت نشده'
                            : 'حقوق محاسبه‌شده‌ی این ماه',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    SectionTitle('وضعیت حساب کارگران در ${month.label}'),
                    _StatusSummary(
                      debtor: countOf(AccountStatus.debtor),
                      creditor: countOf(AccountStatus.creditor),
                      paid: countOf(AccountStatus.paid),
                      empty: monthAccounts.isEmpty,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    SectionTitle(
                      'آخرین پرداخت‌ها',
                      trailing: recent.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () =>
                                  ShellScope.of(context)(AppTab.payments),
                              child: const Text('همه'),
                            ),
                    ),
                    _RecentPayments(entries: recent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two items side by side, stacked on very narrow screens.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.cardGap),
              second,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.debtor,
    required this.creditor,
    required this.paid,
    required this.empty,
  });

  final int debtor;
  final int creditor;
  final int paid;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    if (empty) {
      return const AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.event_busy_outlined,
          title: 'حسابی برای این ماه ثبت نشده است',
          message: 'پس از ثبت حقوق ماهانه در سرور، وضعیت‌ها اینجا نمایش داده می‌شود.',
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _StatusTile(status: AccountStatus.debtor, count: debtor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatusTile(status: AccountStatus.creditor, count: creditor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatusTile(status: AccountStatus.paid, count: paid),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.status, required this.count});

  final AccountStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      AccountStatus.debtor => (AppColors.debtorBg, AppColors.debtorText),
      AccountStatus.creditor => (AppColors.creditorBg, AppColors.creditorText),
      _ => (AppColors.paidBg, AppColors.paidText),
    };
    return Semantics(
      label: '${status.fallbackLabel}: ${formatCount(count)} کارگر',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(formatCount(count), style: AppText.amount.copyWith(color: fg)),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadii.badge),
              ),
              child: Text(
                status.fallbackLabel,
                style: AppText.label.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text('کارگر', style: AppText.secondary),
          ],
        ),
      ),
    );
  }
}

class _RecentPayments extends StatelessWidget {
  const _RecentPayments({required this.entries});

  final List<PaymentEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.receipt_long_outlined,
          title: 'هنوز پرداختی ثبت نشده است',
          actionLabel: 'ثبت پرداخت جدید',
          onAction: () => startPaymentFlow(context),
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            PaymentRow(
              entry: entries[i],
              onTap: () => showPaymentDetailsDialog(context, entries[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: const [
        SkeletonBox(width: 160, height: 28),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 48, radius: AppRadii.button),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 150, radius: AppRadii.card),
        SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 120, radius: AppRadii.card)),
            SizedBox(width: AppSpacing.cardGap),
            Expanded(child: SkeletonBox(height: 120, radius: AppRadii.card)),
          ],
        ),
        SizedBox(height: AppSpacing.sectionGap),
        SkeletonList(count: 4),
      ],
    );
  }
}
