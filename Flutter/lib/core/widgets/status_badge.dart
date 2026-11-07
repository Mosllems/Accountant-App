import 'package:flutter/material.dart';

import '../../models/worker.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Account status badge: soft color + icon + text (never color alone).
/// The status always comes from the backend.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final AccountStatus status;

  /// Backend `status_display`; falls back to the enum label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      AccountStatus.debtor => (
        AppColors.debtorBg,
        AppColors.debtorText,
        Icons.arrow_upward_rounded,
      ),
      AccountStatus.creditor => (
        AppColors.creditorBg,
        AppColors.creditorText,
        Icons.arrow_downward_rounded,
      ),
      AccountStatus.paid => (
        AppColors.paidBg,
        AppColors.paidText,
        Icons.check_rounded,
      ),
      AccountStatus.unknown => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
        Icons.help_outline_rounded,
      ),
    };
    final text = (label == null || label!.isEmpty)
        ? status.fallbackLabel
        : label!;
    return Semantics(
      label: 'وضعیت: $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs - 1,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.badge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: AppText.label.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
