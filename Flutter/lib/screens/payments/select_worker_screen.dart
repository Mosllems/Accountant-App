import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../common/snapshot_view.dart';
import 'register_payment_screen.dart';

/// Step 1 of "new payment" from the payments tab: choose an active worker.
class SelectWorkerScreen extends StatefulWidget {
  const SelectWorkerScreen({super.key});

  @override
  State<SelectWorkerScreen> createState() => _SelectWorkerScreenState();
}

class _SelectWorkerScreenState extends State<SelectWorkerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انتخاب کارگر')),
      body: SnapshotView(
        skeleton: const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: SkeletonList(),
        ),
        builder: (context, data) {
          final workers = data.activeWorkers
              .where((w) => matchesSearch(w.name, _query))
              .toList();
          return ContentWidth(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: SearchField(
                    hint: 'نام کارگر',
                    initialValue: _query,
                    onSearch: (q) => setState(() => _query = q),
                  ),
                ),
                Expanded(
                  child: workers.isEmpty
                      ? EmptyState(
                          icon: Icons.person_search_outlined,
                          title: _query.isEmpty
                              ? 'کارگر فعالی وجود ندارد'
                              : 'کارگری با این نام یافت نشد',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            0,
                            AppSpacing.page,
                            AppSpacing.xl,
                          ),
                          itemCount: workers.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final w = workers[i];
                            final account = w.latestAccount;
                            return AppCard(
                              onTap: () => Navigator.of(context)
                                  .pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          RegisterPaymentScreen(worker: w),
                                    ),
                                  ),
                              child: Row(
                                children: [
                                  const LeadingIcon(Icons.person_outline),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(w.name, style: AppText.bodyStrong),
                                        if (account != null)
                                          Text(
                                            'مانده ${account.yearMonth?.label ?? ''}: ${formatMoneyAbs(account.balance)}',
                                            style: AppText.secondary,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (account != null)
                                    StatusBadge(
                                      status: account.status,
                                      label: account.statusLabel,
                                    ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            );
                          },
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
