import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// One bar group: a month and one or two values.
class MonthValues {
  const MonthValues(this.month, this.values);

  final YearMonth month;
  final List<num> values;
}

/// Restrained bar chart for monthly money values (1 or 2 series).
///
/// Readability aids:
/// - "nice" round axis steps (1/2/5 × 10ⁿ million toman),
/// - a small value label above every non-zero bar,
/// - tap a bar → dashed guide line to the axis with its value, the other
///   bars fade, and the exact amount in toman appears under the chart.
/// Screen readers get [semanticsSummary] instead of the drawing.
class MonthlyBarChart extends StatefulWidget {
  const MonthlyBarChart({
    super.key,
    required this.data,
    required this.seriesLabels,
    required this.semanticsSummary,
  });

  final List<MonthValues> data;
  final List<String> seriesLabels;
  final String semanticsSummary;

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  static const _colors = [AppColors.chartPrimary, AppColors.chartSecondary];
  static const _labelColors = [AppColors.chartPrimary, AppColors.textSecondary];

  int? _group;
  int? _rod;

  @override
  void didUpdateWidget(MonthlyBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New month window → old selection would point at a different bar.
    if (oldWidget.data.first.month != widget.data.first.month) {
      _group = null;
      _rod = null;
    }
  }

  /// Rounds a raw step up to 1, 2 or 5 × 10ⁿ.
  static double _niceStep(double raw) {
    if (raw <= 0) return 1000000;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
    return nice * exp;
  }

  void _onTouch(FlTouchEvent event, BarTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final spot = response?.spot;
    setState(() {
      if (spot == null ||
          (spot.touchedBarGroupIndex == _group &&
              spot.touchedRodDataIndex == _rod)) {
        _group = null; // tap empty area or same bar again → clear
        _rod = null;
      } else {
        _group = spot.touchedBarGroupIndex;
        _rod = spot.touchedRodDataIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final two = widget.seriesLabels.length > 1;
    final maxV = data
        .expand((d) => d.values)
        .fold<num>(0, (m, v) => v > m ? v : m)
        .toDouble();
    final step = _niceStep(maxV / 4);
    var top = step * (maxV / step).ceil();
    if (top <= 0) top = step;
    if (top - maxV < step * 0.25) top += step; // room for value labels

    final selected = _group != null && _rod != null;
    final selectedValue = selected ? data[_group!].values[_rod!] : null;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: widget.semanticsSummary,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Legend(labels: widget.seriesLabels, colors: _colors),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 240,
            // Drawn left-to-right (chronological) for clarity.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: BarChart(
                BarChartData(
                  maxY: top,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.chartGrid,
                      strokeWidth: 1,
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (selectedValue != null)
                        HorizontalLine(
                          y: selectedValue.toDouble(),
                          color: AppColors.navy.withValues(alpha: 0.7),
                          strokeWidth: 1.2,
                          dashArray: const [5, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(left: 2, bottom: 2),
                            style: AppText.label.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              backgroundColor: AppColors.surface,
                            ),
                            labelResolver: (line) => formatMillions(line.y),
                          ),
                        ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: step,
                        getTitlesWidget: (value, meta) {
                          // Only exact grid steps (avoids odd edge labels).
                          final k = value / step;
                          if ((k - k.round()).abs() > 0.001) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            formatMillions(value),
                            style: AppText.secondary.copyWith(fontSize: 11),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              monthName(data[i].month.month),
                              style: AppText.secondary.copyWith(
                                fontSize: 10,
                                fontWeight: i == _group
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Value labels above bars are drawn with always-on,
                  // transparent tooltips; taps are handled by _onTouch.
                  barTouchData: BarTouchData(
                    handleBuiltInTouches: false,
                    touchCallback: _onTouch,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 2,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          rod.toY <= 0
                          ? null
                          : BarTooltipItem(
                              formatMillions(rod.toY),
                              AppText.secondary.copyWith(
                                fontSize: two ? 9 : 10,
                                fontWeight: FontWeight.w600,
                                color: _labelColors[rodIndex],
                              ),
                            ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        showingTooltipIndicators: [
                          for (var s = 0; s < data[i].values.length; s++)
                            if (!selected || (i == _group && s == _rod)) s,
                        ],
                        barRods: [
                          for (var s = 0; s < data[i].values.length; s++)
                            BarChartRodData(
                              toY: data[i].values[s].toDouble(),
                              color: _colors[s].withValues(
                                alpha: !selected || (i == _group && s == _rod)
                                    ? 1
                                    : 0.3,
                              ),
                              width: two ? 12 : 20,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                duration: animate
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Exact amount for the tapped bar (or a hint).
          AnimatedSwitcher(
            duration: animate
                ? const Duration(milliseconds: 150)
                : Duration.zero,
            child: Text(
              key: ValueKey('${_group}_$_rod'),
              selectedValue == null
                  ? 'برای دیدن مبلغ دقیق، روی یک ستون بزنید.'
                  : '${data[_group!].month.label} · '
                        '${widget.seriesLabels[_rod!]}: '
                        '${formatMoney(selectedValue)}',
              textAlign: TextAlign.center,
              style: selectedValue == null
                  ? AppText.secondary
                  : AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.labels, required this.colors});

  final List<String> labels;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(labels[i], style: AppText.secondary),
            ],
          ),
        const Text('(ارقام به میلیون تومان)', style: AppText.secondary),
      ],
    );
  }
}
