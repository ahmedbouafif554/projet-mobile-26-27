import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import '../utils/formatters.dart';

// =============================================================================
// Graphiques fl_chart communs aux deux apps. Ils « se dessinent » à
// l'apparition : la valeur affichée passe de 0 à 100 % en [AppDurations.counter].
// =============================================================================

/// Animation 0 → 1 partagée par les graphiques.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.builder});

  final Widget Function(double progress) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppDurations.counter,
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => builder(t),
  );
}

/// Intervalle « rond » (1 ; 1,5 ; 2 ; 2,5 ; 3 ; 4 ; 5 ; 6 ; 8 × 10ⁿ) pour
/// 4 graduations au-dessus de [maxValue], avec un peu de marge.
double niceInterval(double maxValue, {bool integer = false}) {
  if (maxValue <= 0) return 1;
  final raw = maxValue * 1.1 / 4;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  var interval = 10 * magnitude;
  for (final step in const [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
    if (step * magnitude >= raw) {
      interval = step * magnitude;
      break;
    }
  }
  return integer ? math.max(1, interval.ceilToDouble()) : interval;
}

TextStyle? _axisStyle(BuildContext context) =>
    context.text.labelSmall?.copyWith(color: context.palette.textSecondary);

/// Courbe (ex. ventes sur 7 jours), avec dégradé sous la ligne.
class AppLineChart extends StatelessWidget {
  const AppLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AppColors.primary,
    this.formatValue = Formatters.priceShort,
  }) : assert(values.length == labels.length);

  final List<double> values;
  final List<String> labels;
  final Color color;
  final String Function(num value) formatValue;

  @override
  Widget build(BuildContext context) {
    final interval = niceInterval(values.fold<double>(0, math.max));
    final maxY = interval * 4;

    return _Reveal(
      builder: (t) => LineChart(
        duration: Duration.zero,
        LineChartData(
          minY: 0,
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: context.palette.border,
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    Formatters.compact(value),
                    style: _axisStyle(context),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= labels.length || value != i) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(labels[i], style: _axisStyle(context)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.secondary,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${labels[s.x.round()]}\n${formatValue(values[s.x.round()])}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (i, v) in values.indexed)
                  FlSpot(i.toDouble(), v * t),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: context.colors.surface,
                      strokeWidth: 2.5,
                      strokeColor: color,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Part d'un camembert.
class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Camembert en anneau (ex. commandes par statut) avec légende.
/// L'anneau se remplit dans le sens des aiguilles d'une montre.
class AppPieChart extends StatelessWidget {
  const AppPieChart({super.key, required this.slices, this.centerLabel});

  final List<ChartSlice> slices;

  /// Texte au centre de l'anneau (ex. total).
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    final visible = slices.where((s) => s.value > 0).toList();

    final pie = _Reveal(
      builder: (t) => Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            duration: Duration.zero,
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 46,
              sections: [
                for (final s in visible)
                  PieChartSectionData(
                    value: s.value * t,
                    color: s.color,
                    radius: 22,
                    showTitle: false,
                  ),
                // Partie encore « à dessiner ».
                if (t < 1 && total > 0)
                  PieChartSectionData(
                    value: total * (1 - t),
                    color: Colors.transparent,
                    radius: 22,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          if (centerLabel != null)
            Opacity(
              opacity: t,
              child: Text(centerLabel!, style: context.text.titleLarge),
            ),
        ],
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    s.label,
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  total == 0 ? '0 %' : '${(s.value / total * 100).round()} %',
                  style: context.text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth > 360
          ? Row(
              children: [
                Expanded(child: pie),
                const SizedBox(width: AppSizes.md),
                Flexible(child: legend),
              ],
            )
          : Column(
              children: [
                Expanded(child: pie),
                const SizedBox(height: AppSizes.sm),
                legend,
              ],
            ),
    );
  }
}

/// Barre d'un histogramme.
class ChartBar {
  const ChartBar({required this.label, required this.value});

  final String label;
  final double value;
}

/// Histogramme vertical (ex. top produits) : les barres montent à
/// l'apparition, l'info-bulle affiche le libellé complet.
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    super.key,
    required this.bars,
    this.color = AppColors.primary,
    this.formatValue = Formatters.count,
  });

  final List<ChartBar> bars;
  final Color color;
  final String Function(num value) formatValue;

  /// « Classic Cheeseburger » → « Classic… »
  static String _short(String label) =>
      label.length <= 9 ? label : '${label.substring(0, 8)}…';

  @override
  Widget build(BuildContext context) {
    final interval = niceInterval(
      bars.fold<double>(0, (m, b) => math.max(m, b.value)),
      integer: true,
    );
    final maxY = interval * 4;

    return _Reveal(
      builder: (t) => BarChart(
        duration: Duration.zero,
        BarChartData(
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: context.palette.border,
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: interval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    Formatters.compact(value),
                    style: _axisStyle(context),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _short(bars[value.toInt()].label),
                    style: _axisStyle(context),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.secondary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    '${bars[groupIndex].label}\n'
                    '${formatValue(bars[groupIndex].value)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
          barGroups: [
            for (final (i, bar) in bars.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: bar.value * t,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [color.withValues(alpha: 0.65), color],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
