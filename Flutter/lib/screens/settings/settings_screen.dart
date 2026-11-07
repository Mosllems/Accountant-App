import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/format/digits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_header.dart';

/// Creator credit (confirmed by the owner).
const String _creatorName = 'مسلم امیری';

/// Intentionally simple settings: app info + creator.
/// No account/logout section: the app has no authentication yet.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(title: 'تنظیمات'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('درباره‌ی برنامه'),
                      AppCard(
                        child: Column(
                          children: [
                            const _Tile(
                              icon: Icons.apps_outlined,
                              label: 'نام برنامه',
                              value: 'جهان سنگ',
                            ),
                            const Divider(height: AppSpacing.lg),
                            FutureBuilder<PackageInfo>(
                              future: PackageInfo.fromPlatform(),
                              builder: (context, snap) => _Tile(
                                icon: Icons.info_outline,
                                label: 'نسخه',
                                value: snap.hasData
                                    ? toPersianDigits(snap.data!.version)
                                    : snap.hasError
                                    ? '—'
                                    : '…',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      const SectionTitle('سازنده'),
                      const AppCard(
                        child: _Tile(
                          icon: Icons.code_outlined,
                          label: 'طراحی و توسعه',
                          value: _creatorName,
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
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: AppText.body)),
        Text(value, style: AppText.bodyStrong),
      ],
    );
  }
}
