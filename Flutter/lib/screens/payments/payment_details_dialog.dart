import 'package:flutter/material.dart';

import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_header.dart';
import '../../services/payroll_repository.dart';

/// Read-only payment details in a centered dialog.
Future<void> showPaymentDetailsDialog(
  BuildContext context,
  PaymentEntry entry,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final p = entry.payment;
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          0,
        ),
        title: const Row(
          children: [
            LeadingIcon(Icons.receipt_long_outlined, color: AppColors.navy),
            SizedBox(width: AppSpacing.md),
            Text('جزئیات پرداخت'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  children: [
                    const Text('مبلغ پرداخت', style: AppText.label),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formatMoney(p.amount), style: AppText.amount),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              InfoRow(
                label: 'کارگر',
                value: entry.worker.name,
                emphasize: true,
              ),
              InfoRow(label: 'تاریخ پرداخت', value: formatApiDateLong(p.date)),
              if (entry.account.yearMonth != null)
                InfoRow(
                  label: 'بابت حساب ماه',
                  value: entry.account.yearMonth!.label,
                ),
              if (p.description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text('توضیحات', style: AppText.label),
                const SizedBox(height: AppSpacing.xs),
                Text(p.description!, style: AppText.body),
              ],
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('بستن'),
            ),
          ),
        ],
      );
    },
  );
}
