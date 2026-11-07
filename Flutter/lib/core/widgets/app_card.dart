import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// White content card with the standard border, radius and padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Dark navy card reserved for the most important financial figure.
class DarkSummaryCard extends StatelessWidget {
  const DarkSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    this.footer,
    this.icon = Icons.account_balance_wallet_outlined,
  });

  final String title;
  final String amount;
  final String? footer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title: $amount',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl - 4),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.onDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Icon(icon, color: AppColors.onDark, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.body.copyWith(color: AppColors.onDarkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                amount,
                style: AppText.amount.copyWith(
                  color: AppColors.onDark,
                  fontSize: 28,
                ),
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                footer!,
                style: AppText.secondary.copyWith(color: AppColors.onDarkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small white stat card: icon, label, value.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.action,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  /// Optional compact action at the end of the title row (e.g. an add
  /// button). Kept outside the card's merged semantics so it stays tappable
  /// for screen readers.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final info = Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Same row height with or without an action button.
            height: action == null ? null : AppSpacing.minTouch - 8,
            child: Row(
              children: [
                Icon(icon, color: AppColors.iconAccent, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label, style: AppText.label)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: AppText.amountSmall.copyWith(fontSize: 18),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(caption!, style: AppText.secondary),
          ],
        ],
      ),
    );
    return AppCard(
      child: action == null
          ? info
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: info),
                const SizedBox(width: AppSpacing.xs),
                action!,
              ],
            ),
    );
  }
}

/// Label/value line inside cards and dialogs.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasize ? AppText.bodyStrong : AppText.body,
            ),
          ),
        ],
      ),
    );
  }
}
