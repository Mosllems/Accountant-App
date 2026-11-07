import 'package:flutter/material.dart';

import '../format/digits.dart';
import '../format/jalali.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shared Persian month selector: previous / label (tap → picker) / next.
/// «ماه جاری» and «ماه قبل» live inside the picker dialog.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final YearMonth value;
  final ValueChanged<YearMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // RTL: the start (right) side goes back in time. Chevron icons are
              // auto-mirrored in RTL (matchTextDirection), so use the LTR name.
              IconButton(
                tooltip: 'ماه قبل',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onChanged(value.previous),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  onTap: () async {
                    final picked = await showMonthYearPicker(context, value);
                    if (picked != null) onChanged(picked);
                  },
                  child: Semantics(
                    button: true,
                    label:
                        'ماه انتخاب‌شده: ${value.label}. برای انتخاب ماه لمس کنید',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: AppColors.iconAccent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(value.label, style: AppText.bodyStrong),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'ماه بعد',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onChanged(value.next),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog to pick a Jalali month + year directly.
Future<YearMonth?> showMonthYearPicker(
  BuildContext context,
  YearMonth initial,
) {
  return showDialog<YearMonth>(
    context: context,
    builder: (_) => _MonthYearDialog(initial: initial),
  );
}

class _MonthYearDialog extends StatefulWidget {
  const _MonthYearDialog({required this.initial});

  final YearMonth initial;

  @override
  State<_MonthYearDialog> createState() => _MonthYearDialogState();
}

class _MonthYearDialogState extends State<_MonthYearDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final current = YearMonth.current();
    return AlertDialog(
      title: const Text('انتخاب ماه'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _YearStepper(
              year: _year,
              onChanged: (y) => setState(() => _year = y),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.2,
              children: [
                for (var m = 1; m <= 12; m++)
                  _GridCell(
                    label: monthName(m),
                    selected: widget.initial == YearMonth(_year, m),
                    highlighted: current == YearMonth(_year, m),
                    onTap: () => Navigator.of(context).pop(YearMonth(_year, m)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(current.previous),
          child: const Text('ماه قبل'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(current),
          child: const Text('ماه جاری'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.navy),
          child: const Text('انصراف'),
        ),
      ],
    );
  }
}

/// Persian calendar date picker with a «امروز» shortcut. Past dates allowed.
Future<Jalali?> showJalaliDatePicker(BuildContext context, {Jalali? initial}) {
  return showDialog<Jalali>(
    context: context,
    builder: (_) => _DatePickerDialog(initial: initial ?? Jalali.now()),
  );
}

class _DatePickerDialog extends StatefulWidget {
  const _DatePickerDialog({required this.initial});

  final Jalali initial;

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late YearMonth _shown = YearMonth.of(widget.initial);
  late Jalali _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final first = Jalali(_shown.year, _shown.month, 1);
    final leading = first.weekDay - 1; // Saturday-first grid
    final days = first.monthLength;
    final today = Jalali.now();

    return AlertDialog(
      title: const Text('انتخاب تاریخ'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatDateLong(_selected), style: AppText.amountSmall),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  tooltip: 'ماه قبل',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _shown = _shown.previous),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final picked = await showMonthYearPicker(context, _shown);
                      if (picked != null) setState(() => _shown = picked);
                    },
                    child: Text(_shown.label, style: AppText.bodyStrong),
                  ),
                ),
                IconButton(
                  tooltip: 'ماه بعد',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _shown = _shown.next),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in jalaliWeekDayInitials)
                  Expanded(
                    child: Center(child: Text(d, style: AppText.label)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                for (var d = 1; d <= days; d++)
                  _DayCell(
                    day: d,
                    selected: _selected == Jalali(_shown.year, _shown.month, d),
                    today: today == Jalali(_shown.year, _shown.month, d),
                    onTap: () => setState(
                      () => _selected = Jalali(_shown.year, _shown.month, d),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _selected = today;
            _shown = YearMonth.of(today);
          }),
          child: const Text('امروز'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.navy),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('تأیید'),
        ),
      ],
    );
  }
}

class _YearStepper extends StatelessWidget {
  const _YearStepper({required this.year, required this.onChanged});

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'سال قبل',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(year - 1),
        ),
        Expanded(
          child: Center(
            child: Text(formatCount(year), style: AppText.sectionTitle),
          ),
        ),
        IconButton(
          tooltip: 'سال بعد',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(year + 1),
        ),
      ],
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        side: BorderSide(
          color: selected || highlighted ? AppColors.accent : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: AppText.body.copyWith(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: CircleBorder(
          side: today && !selected
              ? const BorderSide(color: AppColors.accent)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              formatCount(day),
              style: AppText.body.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only field that opens the Jalali date picker.
class JalaliDateField extends StatelessWidget {
  const JalaliDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showTodayButton = false,
    this.errorText,
  });

  final String label;
  final Jalali? value;
  final ValueChanged<Jalali?> onChanged;
  final bool showTodayButton;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final field = InkWell(
      borderRadius: BorderRadius.circular(AppRadii.field),
      onTap: () async {
        final picked = await showJalaliDatePicker(context, initial: value);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(
          value == null ? 'انتخاب کنید' : formatDateShort(value!),
          style: value == null
              ? AppText.body.copyWith(color: AppColors.textMuted)
              : AppText.body,
        ),
      ),
    );
    if (!showTodayButton) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: () => onChanged(Jalali.now()),
            child: const Text('امروز'),
          ),
        ),
      ],
    );
  }
}
