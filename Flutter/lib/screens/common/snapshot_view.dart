import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/state_views.dart';
import '../../services/api_client.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';

/// Safe Persian message for any error.
String userMessage(Object error) => error is ApiException
    ? error.message
    : 'عملیات انجام نشد. لطفاً دوباره تلاش کنید.';

/// Handles the repository states for a screen:
/// - first load → [skeleton]
/// - first load failed → error state with retry
/// - refreshing → keeps data, thin progress bar on top
/// - refresh failed → keeps data, banner with retry
class SnapshotView extends StatefulWidget {
  const SnapshotView({
    super.key,
    required this.skeleton,
    required this.builder,
  });

  final Widget skeleton;
  final Widget Function(BuildContext context, PayrollSnapshot data) builder;

  @override
  State<SnapshotView> createState() => _SnapshotViewState();
}

class _SnapshotViewState extends State<SnapshotView> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      AppScope.of(context).ensureLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final data = repo.snapshot;
        if (data == null) {
          if (repo.error != null && !repo.isLoading) {
            return Center(
              child: SingleChildScrollView(
                child: ErrorState(
                  message: repo.error!.message,
                  onRetry: repo.refresh,
                ),
              ),
            );
          }
          return widget.skeleton;
        }
        return Column(
          children: [
            if (repo.isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppColors.accentSoft,
              ),
            if (repo.error != null && !repo.isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: InkWell(
                  onTap: repo.refresh,
                  child: NoticeBanner(
                    message:
                        'اطلاعات به‌روز نشد (${repo.error!.message}) — داده‌های قبلی نمایش داده می‌شود. برای تلاش مجدد لمس کنید.',
                    icon: Icons.sync_problem_outlined,
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(child: widget.builder(context, data)),
          ],
        );
      },
    );
  }
}
