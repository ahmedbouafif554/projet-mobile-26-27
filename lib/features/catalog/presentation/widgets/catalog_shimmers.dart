import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/shimmer_box.dart';

/// Squelette de l'accueil pendant le chargement simulé.
class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: ShimmerScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 36, width: 180)),
                SizedBox(width: 60),
                SkeletonBox(width: 44, height: 44, circle: true),
                SizedBox(width: 10),
                SkeletonBox(width: 44, height: 44, circle: true),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            const SkeletonBox(height: 28, width: 260),
            const SizedBox(height: AppSizes.md),
            const SkeletonBox(height: 54, radius: AppSizes.radiusMd),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: List.generate(
                3,
                (i) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: SkeletonBox(height: 92, radius: AppSizes.radiusLg),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                4,
                (i) => const SkeletonBox(
                  width: 64,
                  height: 64,
                  radius: AppSizes.radiusLg,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            const SkeletonBox(height: 160, radius: AppSizes.radiusXl),
            const SizedBox(height: AppSizes.lg),
            const SkeletonBox(height: 22, width: 160),
            const SizedBox(height: AppSizes.md),
            const RestaurantListShimmer(
              count: 3,
              scrollable: false,
              padded: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// Squelette d'une liste de restaurants / produits.
class RestaurantListShimmer extends StatelessWidget {
  const RestaurantListShimmer({
    super.key,
    this.count = 5,
    this.scrollable = true,
    this.padded = true,
  });

  final int count;
  final bool scrollable;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      children: List.generate(
        count,
        (i) => const Padding(
          padding: EdgeInsets.only(bottom: AppSizes.md),
          child: Row(
            children: [
              SkeletonBox(width: 96, height: 96, radius: AppSizes.radiusMd),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 16, width: 150),
                    SizedBox(height: 10),
                    SkeletonBox(height: 12, width: 110),
                    SizedBox(height: 14),
                    SkeletonBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final content = Padding(
      padding: padded
          ? const EdgeInsets.symmetric(
              horizontal: AppSizes.pagePadding,
              vertical: AppSizes.sm,
            )
          : EdgeInsets.zero,
      child: list,
    );

    if (!scrollable) return content;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ShimmerScope(child: content),
    );
  }
}
