import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../models/rating_summary.dart';
import '../../../models/review.dart';
import 'star_rating.dart';

/// Icône associée à un critère de notation.
IconData criterionIcon(ReviewCriterion criterion) => switch (criterion) {
  ReviewCriterion.food => Icons.restaurant_rounded,
  ReviewCriterion.delivery => Icons.delivery_dining_rounded,
  ReviewCriterion.packaging => Icons.inventory_2_rounded,
};

/// Résumé des notes : moyenne, répartition 5→1 en barres animées
/// (touchables pour filtrer) et moyennes par critère.
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({
    super.key,
    required this.summary,
    this.selectedStars,
    this.onStarsTap,
  });

  final RatingSummary summary;
  final int? selectedStars;
  final ValueChanged<int>? onStarsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: summary.average),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      Formatters.rating(value),
                      style: context.text.displaySmall,
                    ),
                  ),
                  StarRatingDisplay(rating: summary.average, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.count(summary.count)} avis',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  children: [
                    for (var stars = 5; stars >= 1; stars--)
                      _DistributionRow(
                        stars: stars,
                        ratio: summary.ratioOf(stars),
                        selected: selectedStars == stars,
                        order: 5 - stars,
                        onTap: onStarsTap == null
                            ? null
                            : () => onStarsTap!(stars),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.criteria.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            Row(
              children: [
                for (final criterion in ReviewCriterion.values)
                  Expanded(
                    child: _CriterionScore(
                      criterion: criterion,
                      value: summary.criteria[criterion] ?? 0,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.stars,
    required this.ratio,
    required this.selected,
    required this.order,
    this.onTap,
  });

  final int stars;
  final double ratio;
  final bool selected;
  final int order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final barColor = selected ? AppColors.primary : context.palette.warning;

    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              child: Text(
                '$stars',
                style: context.text.labelMedium?.copyWith(
                  color: selected ? AppColors.primary : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.star_rounded, size: 13, color: barColor),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 8,
                  color: context.palette.surfaceMuted,
                  alignment: Alignment.centerLeft,
                  // Les barres « poussent » en cascade, de 5★ à 1★.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: Duration(milliseconds: 700 + order * 120),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      child: AnimatedContainer(
                        duration: AppDurations.fast,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${(ratio * 100).round()} %',
                textAlign: TextAlign.right,
                style: context.text.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriterionScore extends StatelessWidget {
  const _CriterionScore({required this.criterion, required this.value});

  final ReviewCriterion criterion;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            criterionIcon(criterion),
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(Formatters.rating(value), style: context.text.titleSmall),
        Text(criterion.label, style: context.text.labelSmall),
      ],
    );
  }
}
