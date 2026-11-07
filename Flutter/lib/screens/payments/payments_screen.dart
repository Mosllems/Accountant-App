import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/format/jalali.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/calendar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/payment_row.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/worker_picker.dart';
import '../../models/worker.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';
import '../common/snapshot_view.dart';
import 'payment_details_dialog.dart';
import 'payment_flow.dart';

/// Payments tab: manual search, worker + date-range filters, paging.
///
/// The API has no server-side search/filter/pagination (BACKEND-GAP
/// (list-query)); the full list is already loaded, so filtering and paging
/// happen locally and stay complete.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const _pageSize = 20;

  String _query = '';
  WorkerDetail? _worker;
  Jalali? _from;
  Jalali? _to;
  int _page = 0;
  int _searchReset = 0;

  bool get _hasFilters =>
      _query.isNotEmpty || _worker != null || _from != null || _to != null;

  void _update(VoidCallback change) => setState(() {
    change();
    _page = 0; // any search/filter change returns to the first page
  });

  List<PaymentEntry> _apply(PayrollSnapshot data) => data.payments.where((e) {
    if (!matchesSearch(e.worker.name, _query)) return false;
    if (_worker != null && e.worker.id != _worker!.id) return false;
    final d = e.payment.jalaliDate;
    if (_from != null && (d == null || d.compareTo(_from!) < 0)) return false;
    if (_to != null && (d == null || d.compareTo(_to!) > 0)) return false;
    return true;
  }).toList();

  Future<void> _pickWorker(PayrollSnapshot data) async {
    final choice = await showWorkerPicker(
      context,
      workers: data.workers,
      selectedId: _worker?.id,
    );
    // null = dialog dismissed → keep the current filter.
    if (choice == null || !mounted) return;
    _update(() => _worker = choice.worker);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: (isStart ? _from : _to) ?? Jalali.now(),
    );
    if (picked == null || !mounted) return;
    final from = isStart ? picked : _from;
    final to = isStart ? _to : picked;
    if (from != null && to != null && from.compareTo(to) > 0) {
      showAppSnackBar(
        context,
        'تاریخ شروع نباید بعد از تاریخ پایان باشد.',
        type: FeedbackType.error,
      );
      return;
    }
    _update(() {
      _from = from;
      _to = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SnapshotView(
        skeleton: const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: SkeletonList(count: 7, rowHeight: 64),
        ),
        builder: (context, data) {
          final filtered = _apply(data);
          final pageCount = (filtered.length / _pageSize).ceil();
          final page = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
          final visible = filtered
              .skip(page * _pageSize)
              .take(_pageSize)
              .toList();

          return RefreshIndicator(
            onRefresh: AppScope.of(context).refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: 'پرداخت‌ها',
                        action: FilledButton.icon(
                          onPressed: () => startPaymentFlow(context),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('ثبت پرداخت'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: SearchField(
                          key: ValueKey(_searchReset),
                          hint: 'جستجوی نام کارگر',
                          initialValue: _query,
                          onSearch: (q) => _update(() => _query = q),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FilterBar(
                        worker: _worker,
                        from: _from,
                        to: _to,
                        hasFilters: _hasFilters,
                        onWorker: () => _pickWorker(data),
                        onFrom: () => _pickDate(isStart: true),
                        onTo: () => _pickDate(isStart: false),
                        onClearWorker: () => _update(() => _worker = null),
                        onClearFrom: () => _update(() => _from = null),
                        onClearTo: () => _update(() => _to = null),
                        onClearAll: () => _update(() {
                          _query = '';
                          _worker = null;
                          _from = null;
                          _to = null;
                          _searchReset++; // also empties the search box
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: visible.isEmpty
                            ? AppCard(
                                child: EmptyState(
                                  compact: true,
                                  icon: _hasFilters
                                      ? Icons.filter_alt_off_outlined
                                      : Icons.receipt_long_outlined,
                                  title: _hasFilters
                                      ? 'نتیجه‌ای با این فیلترها یافت نشد'
                                      : 'هنوز پرداختی ثبت نشده است',
                                ),
                              )
                            : AppCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < visible.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        const Divider(
                                          indent: AppSpacing.lg,
                                          endIndent: AppSpacing.lg,
                                        ),
                                      PaymentRow(
                                        entry: visible[i],
                                        onTap: () => showPaymentDetailsDialog(
                                          context,
                                          visible[i],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                      if (pageCount > 0)
                        _Pager(
                          page: page,
                          pageCount: pageCount,
                          total: filtered.length,
                          onChanged: (p) => setState(() => _page = p),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.worker,
    required this.from,
    required this.to,
    required this.hasFilters,
    required this.onWorker,
    required this.onFrom,
    required this.onTo,
    required this.onClearWorker,
    required this.onClearFrom,
    required this.onClearTo,
    required this.onClearAll,
  });

  final WorkerDetail? worker;
  final Jalali? from;
  final Jalali? to;
  final bool hasFilters;
  final VoidCallback onWorker;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onClearWorker;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;
  final VoidCallback onClearAll;

  /// Filter chip. When active it shows an × that removes only this filter.
  Widget _chip({
    required String label,
    required bool active,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: active ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      onDeleted: active ? onClear : null,
      deleteIcon: const Icon(Icons.close, size: 18),
      deleteIconColor: Colors.white,
      deleteButtonTooltipMessage: 'حذف این فیلتر',
      labelStyle: TextStyle(
        color: active ? Colors.white : AppColors.textPrimary,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(color: active ? AppColors.accent : AppColors.border),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap instead of horizontal scroll: every control stays visible.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _chip(
                label: worker?.name ?? 'همه‌ی کارگران',
                active: worker != null,
                icon: Icons.person_outline,
                onTap: onWorker,
                onClear: onClearWorker,
              ),
              _chip(
                label: from == null
                    ? 'از تاریخ'
                    : 'از ${formatDateShort(from!)}',
                active: from != null,
                icon: Icons.event_outlined,
                onTap: onFrom,
                onClear: onClearFrom,
              ),
              _chip(
                label: to == null ? 'تا تاریخ' : 'تا ${formatDateShort(to!)}',
                active: to != null,
                icon: Icons.event_outlined,
                onTap: onTo,
                onClear: onClearTo,
              ),
            ],
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: hasFilters
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: onClearAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 20,
                        ),
                        label: const Text('حذف همه‌ی فیلترها'),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        0,
      ),
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: 'صفحه‌ی قبل',
            onPressed: page > 0 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'صفحه‌ی ${formatCount(page + 1)} از ${formatCount(pageCount)}',
                  style: AppText.bodyStrong,
                ),
                Text('${formatCount(total)} پرداخت', style: AppText.secondary),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'صفحه‌ی بعد',
            onPressed: page < pageCount - 1 ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
