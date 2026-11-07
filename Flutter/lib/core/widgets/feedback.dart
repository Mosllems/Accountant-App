import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

enum FeedbackType { success, error, info }

/// Short, auto-dismissing Persian SnackBar. Replaces any visible one so the
/// same error is never shown twice at once.
void showAppSnackBar(
  BuildContext context,
  String message, {
  FeedbackType type = FeedbackType.info,
}) {
  final (color, icon) = switch (type) {
    FeedbackType.success => (AppColors.success, Icons.check_circle_outline),
    FeedbackType.error => (AppColors.error, Icons.error_outline),
    FeedbackType.info => (AppColors.navy, Icons.info_outline),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Confirmation dialog for destructive actions.
///
/// [onConfirm] runs inside the dialog; the confirm button is disabled while
/// it runs (no double submission). Returns true if it completed, false if
/// cancelled. If [onConfirm] throws, the error message is shown in the
/// dialog and the user can retry or cancel.
Future<bool> showDestructiveConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
  required String Function(Object error) errorMessage,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
      errorMessage: errorMessage,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    required this.errorMessage,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final String Function(Object error) errorMessage;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 32,
        ),
        title: Text(widget.title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message, style: AppText.body),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppText.secondary.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.navy),
            child: const Text('انصراف'),
          ),
          DestructiveButton(
            label: widget.confirmLabel,
            loading: _busy,
            onPressed: _run,
          ),
        ],
      ),
    );
  }
}
