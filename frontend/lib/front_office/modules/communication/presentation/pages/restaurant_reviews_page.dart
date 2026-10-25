import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../catalog/providers/catalog_providers.dart';
import '../../providers/communication_providers.dart';
import '../widgets/review_card.dart';

/// Avis publiés d'un restaurant : moyenne, répartition, filtres et « Utile ».
class RestaurantReviewsPage extends ConsumerStatefulWidget {
  const RestaurantReviewsPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<RestaurantReviewsPage> createState() =>
      _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends ConsumerState<RestaurantReviewsPage> {
  /// null = tous, 0 = avec photos, 1–5 = nombre d'étoiles.
  int? _filter;

  @override
  Widget build(BuildContext context) {
    final restaurant = ref.watch(restaurantProvider(widget.restaurantId)).value;
    final reviews = ref.watch(restaurantReviewsProvider(widget.restaurantId));
    final helpful = ref.watch(helpfulReviewsProvider);
    final all = reviews.value ?? const <Review>[];
    final visible = all.where((r) {
      if (_filter == null) return true;
      if (_filter == 0) return r.photos.isNotEmpty;
      return r.rating == _filter;
    }).toList();
    final average = all.isEmpty
        ? (restaurant?.rating ?? 0)
        : all.fold<int>(0, (s, r) => s + r.rating) / all.length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children: [
            const PageTitle('Avis clients'),
            if (restaurant != null)
              Text(
                restaurant.name,
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                boxShadow: context.palette.softShadow,
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        Formatters.rating(average),
                        style: context.text.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      RatingStars(rating: average),
                      const SizedBox(height: 4),
                      Text(
                        '${Formatters.compact(restaurant?.reviewCount ?? all.length)} avis',
                        style: context.text.labelSmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSizes.lg),
                  Expanded(
                    child: Column(
                      children: [
                        for (var star = 5; star >= 1; star--)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  child: Text(
                                    '$star',
                                    style: context.text.labelSmall,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: all.isEmpty
                                          ? 0
                                          : all
                                                    .where((r) => r.rating == star)
                                                    .length /
                                                all.length,
                                    ),
                                    duration: AppDurations.slow,
                                    builder: (context, v, _) => ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: v,
                                        minHeight: 7,
                                        color: AppColors.warning,
                                        backgroundColor:
                                            context.palette.surfaceMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: AppSizes.md),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (value, label) in [
                    (null, 'Tous'),
                    (0, 'Avec photos'),
                    (5, '5 ★'),
                    (4, '4 ★'),
                    (3, '3 ★'),
                    (2, '2 ★'),
                    (1, '1 ★'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.sm),
                      child: SelectableChip(
                        label: label,
                        selected: _filter == value,
                        onTap: () => setState(() => _filter = value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),
            if (reviews.isLoading && reviews.value == null)
              const ShimmerScope(
                child: Column(
                  children: [
                    SkeletonBox(height: 120, radius: AppSizes.radiusLg),
                    SizedBox(height: AppSizes.md),
                    SkeletonBox(height: 120, radius: AppSizes.radiusLg),
                  ],
                ),
              )
            else if (visible.isEmpty)
              const EmptyState(
                compact: true,
                icon: Icons.reviews_outlined,
                title: 'Aucun avis',
                message: 'Aucun avis ne correspond à ce filtre.',
              )
            else
              for (final (i, r) in visible.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                  child: ReviewCard(
                    review: r,
                    footer: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: helpful.contains(r.id)
                            ? null
                            : () => ref
                                  .read(helpfulReviewsProvider.notifier)
                                  .mark(r),
                        icon: Icon(
                          helpful.contains(r.id)
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 18,
                        ),
                        label: Text('Utile (${r.helpfulCount})'),
                      ),
                    ),
                  ).animate(delay: (40 * (i % 8)).ms).fadeIn().slideY(begin: 0.05),
                ),
          ],
        ),
      ),
    );
  }
}
