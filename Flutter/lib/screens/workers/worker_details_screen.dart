import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/calendar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/payment_row.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/worker.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';
import '../common/snapshot_view.dart';
import '../payments/payment_details_dialog.dart';
import '../payments/payment_flow.dart';

/// Accounting overview of one worker for a selected month.
class WorkerDetailsScreen extends StatefulWidget {
  const WorkerDetailsScreen({super.key, required this.workerId});

  final int workerId;

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  YearMonth? _month;

  /// Default month: current month if it has an account, else the latest one.
  YearMonth _monthFor(WorkerDetail w) {
    if (_month != null) return _month!;
    final current = YearMonth.current();
    if (w.accountFor(current) != null) return current;
    return w.latestAccount?.yearMonth ?? current;
  }

  Future<void> _delete(WorkerDetail worker) async {
    final repo = AppScope.of(context);
    final deleted = await showDestructiveConfirm(
      context,
      title: 'حذف کارگر',
      message:
          'آیا از حذف «${worker.name}» مطمئن هستید؟\n'
          'با حذف کارگر، تمام حقوق‌های ماهانه، حساب‌ها و پرداخت‌های او نیز '
          'برای همیشه حذف می‌شوند و قابل بازگشت نیست.',
      confirmLabel: 'حذف کارگر',
      onConfirm: () => repo.deleteWorker(worker.id),
      errorMessage: userMessage,
    );
    if (!deleted || !mounted) return;
    showAppSnackBar(context, 'کارگر حذف شد.', type: FeedbackType.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final worker = AppScope.of(context).snapshot?.workerById(widget.workerId);
    return Scaffold(
      appBar: AppBar(
        title: Text(worker?.name ?? 'جزئیات کارگر'),
        actions: [
          if (worker != null)
            PopupMenuButton<String>(
              tooltip: 'گزینه‌های بیشتر',
              onSelected: (_) => _delete(worker),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'حذف کارگر',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SnapshotView(
        skeleton: const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: SkeletonList(count: 4, rowHeight: 110),
        ),
        builder: (context, data) {
          final w = data.workerById(widget.workerId);
          if (w == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'این کارگر یافت نشد',
              message: 'ممکن است حذف شده باشد.',
            );
          }
          final month = _monthFor(w);
          final account = w.accountFor(month);
          return RefreshIndicator(
            onRefresh: AppScope.of(context).refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WorkerInfo(worker: w),
                      const SizedBox(height: AppSpacing.sectionGap),
                      MonthSelector(
                        value: month,
                        onChanged: (m) => setState(() => _month = m),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (account == null)
                        AppCard(
                          child: EmptyState(
                            compact: true,
                            icon: Icons.event_busy_outlined,
                            title: 'برای ${month.label} حسابی ثبت نشده است',
                          ),
                        )
                      else
                        _MonthAccount(worker: w, account: account),
                      const SizedBox(height: AppSpacing.xl),
                      if (w.isActive)
                        PrimaryButton(
                          label: 'ثبت پرداخت برای این کارگر',
                          icon: Icons.add_card_outlined,
                          expand: true,
                          onPressed: () => startPaymentFlow(context, worker: w),
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
}

class _WorkerInfo extends StatelessWidget {
  const _WorkerInfo({required this.worker});

  final WorkerDetail worker;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.navy,
            child: Text(
              worker.name.isEmpty ? '?' : worker.name.characters.first,
              style: AppText.sectionTitle.copyWith(color: AppColors.onDark),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name, style: AppText.sectionTitle),
                Text(
                  'شروع کار: ${formatApiDateLong(worker.startDate)}',
                  style: AppText.secondary,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: worker.isActive
                  ? AppColors.accentSoft
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.badge),
            ),
            child: Text(
              worker.isActive ? 'فعال' : 'غیرفعال',
              style: AppText.label.copyWith(
                color: worker.isActive
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthAccount extends StatelessWidget {
  const _MonthAccount({required this.worker, required this.account});

  final WorkerDetail worker;
  final MonthlyAccount account;

  @override
  Widget build(BuildContext context) {
    final payments = [...account.payments]..sort((a, b) => b.compareByDate(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Financial summary: white card, large amount, status badge.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('مانده‌ی حساب', style: AppText.label),
                  ),
                  StatusBadge(
                    status: account.status,
                    label: account.statusLabel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  formatMoneyAbs(account.balance),
                  style: AppText.amount,
                ),
              ),
              if (account.settledAt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'تاریخ تسویه: ${formatApiDateLong(account.settledAt)}',
                  style: AppText.secondary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('حقوق این ماه'),
              InfoRow(
                label: 'حقوق پایه‌ی ماهانه',
                value: formatMoney(account.monthlySalary?.salary),
              ),
              InfoRow(
                label: 'روزهای مشمول',
                value: account.eligibleDays == null
                    ? missingValue
                    : '${formatCount(account.eligibleDays!)} روز',
              ),
              InfoRow(
                label: 'حقوق روزانه',
                value: formatMoney(account.dailySalary),
              ),
              const Divider(height: AppSpacing.lg),
              InfoRow(
                label: 'حقوق محاسبه‌شده',
                value: formatMoney(account.calculatedAmount),
                emphasize: true,
              ),
              InfoRow(
                label: 'مجموع پرداخت‌ها',
                value: formatMoney(account.totalPayments),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionTitle('پرداخت‌های ${account.yearMonth?.label ?? ''}'),
        if (payments.isEmpty)
          const AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'پرداختی برای این ماه ثبت نشده است',
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < payments.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                  Builder(
                    builder: (context) {
                      final entry = PaymentEntry(
                        payment: payments[i],
                        worker: worker,
                        account: account,
                      );
                      return PaymentRow(
                        entry: entry,
                        showWorker: false,
                        onTap: () => showPaymentDetailsDialog(context, entry),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
