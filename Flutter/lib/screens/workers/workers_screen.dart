import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import '../../models/worker.dart';
import '../../services/app_scope.dart';
import '../common/snapshot_view.dart';
import '../payments/payment_flow.dart';
import 'add_worker_screen.dart';
import 'worker_card.dart';
import 'worker_details_screen.dart';

enum _StatusFilter { all, debtor, creditor, paid }

enum _Sort { name, mostDebt, mostCredit, lastPayment }

const _sortLabels = {
  _Sort.name: 'نام',
  _Sort.mostDebt: 'بیشترین بدهی',
  _Sort.mostCredit: 'بیشترین طلب',
  _Sort.lastPayment: 'آخرین پرداخت',
};

/// Workers tab: manual search, status filter, sort, worker cards.
/// Status/balance come from each worker's latest backend monthly account.
class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;
  _Sort _sort = _Sort.name;

  bool _matchesFilter(WorkerDetail w) {
    if (_filter == _StatusFilter.all) return true;
    final status = w.latestAccount?.status;
    return switch (_filter) {
      _StatusFilter.debtor => status == AccountStatus.debtor,
      _StatusFilter.creditor => status == AccountStatus.creditor,
      _StatusFilter.paid => status == AccountStatus.paid,
      _StatusFilter.all => true,
    };
  }

  /// Magnitude for "most debt/credit" sorting — only accounts the backend
  /// marked with that status rank; others go last. Never infers status.
  num _rank(WorkerDetail w, AccountStatus status) {
    final a = w.latestAccount;
    return (a != null && a.status == status) ? a.balance.abs() : -1;
  }

  List<WorkerDetail> _apply(List<WorkerDetail> all) {
    final list = all
        .where((w) => matchesSearch(w.name, _query) && _matchesFilter(w))
        .toList();
    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _Sort.mostDebt:
        list.sort(
          (a, b) => _rank(
            b,
            AccountStatus.debtor,
          ).compareTo(_rank(a, AccountStatus.debtor)),
        );
      case _Sort.mostCredit:
        list.sort(
          (a, b) => _rank(
            b,
            AccountStatus.creditor,
          ).compareTo(_rank(a, AccountStatus.creditor)),
        );
      case _Sort.lastPayment:
        list.sort((a, b) {
          final pa = a.lastPayment;
          final pb = b.lastPayment;
          if (pa == null && pb == null) return 0;
          if (pa == null) return 1;
          if (pb == null) return -1;
          return pb.compareByDate(pa);
        });
    }
    return list;
  }

  void _openDetails(WorkerDetail w) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WorkerDetailsScreen(workerId: w.id),
    ),
  );

  void _addWorker() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const AddWorkerScreen()));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SnapshotView(
        skeleton: const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: SkeletonList(count: 5, rowHeight: 140),
        ),
        builder: (context, data) {
          final workers = _apply(data.workers);
          final filtered = _query.isNotEmpty || _filter != _StatusFilter.all;
          return RefreshIndicator(
            onRefresh: AppScope.of(context).refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(
                          title: 'کارگران',
                          subtitle: '${formatCount(data.workers.length)} کارگر',
                          action: FilledButton.icon(
                            onPressed: _addWorker,
                            icon: const Icon(
                              Icons.person_add_alt_outlined,
                              size: 20,
                            ),
                            label: const Text('افزودن کارگر'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: SearchField(
                            hint: 'جستجوی نام کارگر',
                            initialValue: _query,
                            onSearch: (q) => setState(() => _query = q),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilterChipBar<_StatusFilter>(
                          selected: _filter,
                          onSelected: (f) => setState(() => _filter = f),
                          options: const [
                            (_StatusFilter.all, 'همه'),
                            (_StatusFilter.debtor, 'بدهکار'),
                            (_StatusFilter.creditor, 'طلبکار'),
                            (_StatusFilter.paid, 'تسویه‌شده'),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${formatCount(workers.length)} نتیجه',
                                  style: AppText.secondary,
                                ),
                              ),
                              PopupMenuButton<_Sort>(
                                tooltip: 'مرتب‌سازی',
                                initialValue: _sort,
                                onSelected: (s) => setState(() => _sort = s),
                                itemBuilder: (_) => [
                                  for (final s in _Sort.values)
                                    PopupMenuItem(
                                      value: s,
                                      child: Text(_sortLabels[s]!),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sort,
                                        size: 20,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'مرتب‌سازی: ${_sortLabels[_sort]}',
                                        style: AppText.body.copyWith(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (workers.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: filtered
                          ? Icons.person_search_outlined
                          : Icons.people_outline,
                      title: filtered
                          ? 'نتیجه‌ای با این فیلترها یافت نشد'
                          : 'کارگری یافت نشد',
                      actionLabel: filtered
                          ? 'پاک کردن فیلترها'
                          : 'افزودن کارگر',
                      onAction: filtered
                          ? () => setState(() {
                              _query = '';
                              _filter = _StatusFilter.all;
                            })
                          : _addWorker,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: workers.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.cardGap),
                      itemBuilder: (context, i) {
                        final w = workers[i];
                        return ContentWidth(
                          child: WorkerCard(
                            worker: w,
                            onOpen: () => _openDetails(w),
                            onPay: w.isActive
                                ? () => startPaymentFlow(context, worker: w)
                                : null,
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
