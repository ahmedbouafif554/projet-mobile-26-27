import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Histogramme simple des commandes de la semaine.
/// Les barres « poussent » en cascade à l'affichage ; touchez-en une
/// pour afficher sa valeur.
class WeeklyChart extends StatefulWidget {
  const WeeklyChart({super.key, required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  late int _selected = widget.values.length - 1;

  @override
  Widget build(BuildContext context) {
    final maxValue = widget.values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Commandes de la semaine', style: context.text.titleMedium),
              const Spacer(),
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: Text(
                  '${widget.values[_selected]}',
                  key: ValueKey(_selected),
                  style: context.text.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          SizedBox(
            // Marge pour le léger dépassement de la courbe « easeOutBack ».
            height: 175,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < widget.values.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: widget.values[i] / maxValue,
                            ),
                            duration: Duration(milliseconds: 600 + i * 90),
                            curve: Curves.easeOutBack,
                            builder: (context, factor, _) => AnimatedContainer(
                              duration: AppDurations.fast,
                              width: 22,
                              height: math.max(0, 118 * factor),
                              decoration: BoxDecoration(
                                gradient: i == _selected
                                    ? AppColors.primaryGradient
                                    : null,
                                color: i == _selected
                                    ? null
                                    : AppColors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.labels[i],
                            style: context.text.labelMedium?.copyWith(
                              color: i == _selected ? AppColors.primary : null,
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
    );
  }
}
