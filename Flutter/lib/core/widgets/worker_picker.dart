import 'package:flutter/material.dart';

import '../../models/worker.dart';
import '../format/digits.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'search_field.dart';
import 'state_views.dart';

/// Result of the worker picker. [worker] == null means «همه‌ی کارگران».
class WorkerChoice {
  const WorkerChoice(this.worker);

  final WorkerDetail? worker;
}

/// Searchable worker picker dialog with an «all workers» option on top.
///
/// Search is local and manual (button / keyboard search) — the API has no
/// server-side search yet (BACKEND-GAP(list-query)). Returns null when the
/// dialog is dismissed without a choice.
Future<WorkerChoice?> showWorkerPicker(
  BuildContext context, {
  required List<WorkerDetail> workers,
  int? selectedId,
}) {
  return showDialog<WorkerChoice>(
    context: context,
    builder: (_) =>
        _WorkerPickerDialog(workers: workers, selectedId: selectedId),
  );
}

class _WorkerPickerDialog extends StatefulWidget {
  const _WorkerPickerDialog({required this.workers, required this.selectedId});

  final List<WorkerDetail> workers;
  final int? selectedId;

  @override
  State<_WorkerPickerDialog> createState() => _WorkerPickerDialogState();
}

class _WorkerPickerDialogState extends State<_WorkerPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list =
        widget.workers.where((w) => matchesSearch(w.name, _query)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final height = MediaQuery.sizeOf(context).height * 0.6;

    return AlertDialog(
      title: const Text('انتخاب کارگر'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: 400,
        height: height,
        child: Column(
          children: [
            SearchField(
              hint: 'نام کارگر',
              onSearch: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_query.isEmpty)
              _Option(
                icon: Icons.groups_outlined,
                label: 'همه‌ی کارگران',
                selected: widget.selectedId == null,
                onTap: () =>
                    Navigator.of(context).pop(const WorkerChoice(null)),
              ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      compact: true,
                      icon: Icons.person_search_outlined,
                      title: 'کارگری با این نام یافت نشد',
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => _Option(
                        icon: Icons.person_outline,
                        label: list[i].name,
                        sublabel: list[i].isActive ? null : 'غیرفعال',
                        selected: list[i].id == widget.selectedId,
                        onTap: () =>
                            Navigator.of(context).pop(WorkerChoice(list[i])),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.navy),
          child: const Text('انصراف'),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: AppColors.accentSoft,
      selectedColor: AppColors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      leading: Icon(
        icon,
        color: selected ? AppColors.accent : AppColors.iconAccent,
      ),
      title: Text(label, style: selected ? AppText.bodyStrong : AppText.body),
      subtitle: sublabel == null
          ? null
          : Text(sublabel!, style: AppText.secondary),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
    );
  }
}

/// Field that shows the current worker choice and opens [showWorkerPicker].
/// Shows an × to go back to «همه‌ی کارگران».
class WorkerSelectField extends StatelessWidget {
  const WorkerSelectField({
    super.key,
    required this.workers,
    required this.selected,
    required this.onChanged,
  });

  final List<WorkerDetail> workers;
  final WorkerDetail? selected;
  final ValueChanged<WorkerDetail?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.field),
      onTap: () async {
        final choice = await showWorkerPicker(
          context,
          workers: workers,
          selectedId: selected?.id,
        );
        if (choice != null) onChanged(choice.worker);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'کارگر',
          prefixIcon: const Icon(Icons.person_search_outlined),
          suffixIcon: selected == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  tooltip: 'نمایش همه‌ی کارگران',
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(selected?.name ?? 'همه‌ی کارگران', style: AppText.body),
      ),
    );
  }
}
