import 'package:flutter/material.dart';

import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/worker.dart';

/// Worker list card. Balance/status are the backend values of the worker's
/// most recent monthly account, labelled with that month.
class WorkerCard extends StatelessWidget {
  const WorkerCard({
    super.key,
    required this.worker,
    required this.onOpen,
    required this.onPay,
  });

  final WorkerDetail worker;
  final VoidCallback onOpen;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final account = worker.latestAccount;
    final last = worker.lastPayment;
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentSoft,
                child: Text(
                  worker.name.isEmpty ? '?' : worker.name.characters.first,
                  style: AppText.cardTitle.copyWith(color: AppColors.accent),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: AppText.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!worker.isActive)
                      Text(
                        'غیرفعال',
                        style: AppText.secondary.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (account != null)
                StatusBadge(status: account.status, label: account.statusLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (account == null)
            const Text(
              'هنوز حساب ماهانه‌ای ثبت نشده است',
              style: AppText.secondary,
            )
          else ...[
            Text(
              'مانده‌ی ${account.yearMonth?.label ?? ''}',
              style: AppText.label,
            ),
            Text(
              formatMoneyAbs(account.balance),
              style: AppText.amountSmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                _Meta(
                  icon: Icons.request_quote_outlined,
                  text: 'حقوق ماه: ${formatMoney(account.calculatedAmount)}',
                ),
                _Meta(
                  icon: Icons.history,
                  text: last == null
                      ? 'بدون پرداخت'
                      : 'آخرین پرداخت: ${formatApiDateLong(last.date)}',
                ),
              ],
            ),
          ],
          if (onPay != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.navy,
                    ),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('جزئیات'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.add_card_outlined, size: 18),
                    label: const Text('ثبت پرداخت'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppText.secondary),
      ],
    );
  }
}
