import 'dart:async';

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
import '../../services/api_client.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';
import '../common/snapshot_view.dart';
import 'payment_details_dialog.dart';
import 'payment_flow.dart';

/// Payments tab: manual search, worker + date-range filters, paging.
///
/// Pages come from the backend (`GET /api/payments/?page=N`); search and
/// filters are sent to the server, so every page and the total count cover
/// all matching payments — never just the rows already loaded.
/// The snapshot is still used for the worker picker.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _query = '';
  WorkerDetail? _worker;
  Jalali? _from;
  Jalali? _to;
  int _page = 1;
  int _searchReset = 0;

  PayrollRepository? _repo;
  PayrollSnapshot? _seenSnapshot;
  PaymentPage? _result;
  ApiException? _error;
  bool _loading = false;

  /// Only the latest request may update the screen (filters can change
  /// while an older page is still loading).
  int _requestId = 0;

  bool get _hasFilters =>
      _query.isNotEmpty || _worker != null || _from != null || _to != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context);
    if (!identical(repo, _repo)) {
      _repo?.removeListener(_onRepositoryChanged);
      _repo = repo..addListener(_onRepositoryChanged);
      _seenSnapshot = repo.snapshot;
      _load();
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  /// Data changed (refresh, new payment, worker deleted) → reload the page.
  void _onRepositoryChanged() {
    final snapshot = _repo?.snapshot;
    if (snapshot == null || identical(snapshot, _seenSnapshot)) return;
    _seenSnapshot = snapshot;
    _load();
  }

  Future<void> _load() async {
    final repo = _repo;
    if (repo == null) return;
    final id = ++_requestId;
    setState(() => _loading = true);
    try {
      final result = await repo.fetchPaymentsPage(
        page: _page,
        search: normalizeForSearch(_query).trim(),
        workerId: _worker?.id,
        from: _from,
        to: _to,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _result = result;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      // The page no longer exists (rows were removed) → back to page 1.
      if (e.kind == ApiErrorKind.notFound && _page > 1) {
        _page = 1;
        unawaited(_load());
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _update(VoidCallback change) {
    change();
    _page = 1; // any search/filter change returns to the first page
    _load();
  }

  void _goToPage(int page) {
    _page = page;
    _load();
  }

  Future<void> _refresh() =>
      Future.wait([AppScope.of(context).refresh(), _load()]);

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

  Widget _list() {
    if (_error != null) {
      return AppCard(
        child: ErrorState(
          compact: true,
          message: _error!.message,
          onRetry: _load,
        ),
      );
    }
    final result = _result;
    if (result == null) return const SkeletonList(count: 7, rowHeight: 64);
    final visible = result.items;
    if (visible.isEmpty) {
      return AppCard(
        child: EmptyState(
          compact: true,
          icon: _hasFilters
              ? Icons.filter_alt_off_outlined
              : Icons.receipt_long_outlined,
          title: _hasFilters
              ? 'نتیجه‌ای با این فیلترها یافت نشد'
              : 'هنوز پرداختی ثبت نشده است',
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            PaymentRow(
              entry: visible[i],
              onTap: () => showPaymentDetailsDialog(context, visible[i]),
            ),
          ],
        ],
      ),
    );
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
          final result = _error == null ? _result : null;
          return RefreshIndicator(
            onRefresh: _refresh,
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
                      // A new page is loading: keep the old rows, thin bar.
                      SizedBox(
                        height: 2,
                        child: _loading && _result != null
                            ? const LinearProgressIndicator(
                                minHeight: 2,
                                backgroundColor: AppColors.accentSoft,
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.page,
                        ),
                        child: _list(),
                      ),
                      if (result != null && result.pageCount > 0)
                        _Pager(
                          page: result.page - 1,
                          pageCount: result.pageCount,
                          total: result.count,
                          enabled: !_loading,
                          onChanged: (p) => _goToPage(p + 1),
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
    required this.enabled,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final int total;

  /// False while a page is loading (prevents double taps).
  final bool enabled;
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
            onPressed: enabled && page > 0 ? () => onChanged(page - 1) : null,
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
            onPressed: enabled && page < pageCount - 1
                ? () => onChanged(page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
