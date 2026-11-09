import 'package:flutter/material.dart';

import '../../services/payroll_repository.dart';
import '../format/jalali.dart';
import '../format/money.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'page_header.dart';

/// One payment line: worker name + amount (prominent), date + description
/// (secondary).
class PaymentRow extends StatelessWidget {
  const PaymentRow({
    super.key,
    required this.entry,
    this.onTap,
    this.showWorker = true,
  });

  final PaymentEntry entry;
  final VoidCallback? onTap;
  final bool showWorker;

  @override
  Widget build(BuildContext context) {
    final p = entry.payment;
    final amount = formatMoney(p.amount);
    final date = formatApiDateLong(p.date);
    final title = showWorker ? entry.workerName : date;
    return Semantics(
      button: onTap != null,
      label: '$title، $amount${showWorker ? '، $date' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const LeadingIcon(Icons.payments_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (showWorker) date,
                        if (p.description != null) p.description!,
                      ].join(' · '),
                      style: AppText.secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(amount, style: AppText.amountSmall),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: AppSpacing.xs),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
