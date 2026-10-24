import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../data/catalog_mock_data.dart';
import '../../models/promotion.dart';
import '../widgets/catalog_shimmers.dart';
import '../widgets/category_item.dart';
import '../widgets/home_header.dart';
import '../widgets/promo_carousel.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_tile.dart';

/// Accueil : recherche, services, catégories, promotions,
/// restaurants populaires et restaurants proches.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Chargement simulé pour montrer l'effet shimmer.
    Future.delayed(AppDurations.fakeLoading, () {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _openPromotion(Promotion promo) {
    if (promo.restaurantId != null) {
      context.push(
        AppRoutes.restaurantDetail(promo.restaurantId!, hero: 'promo'),
      );
    } else {
      context.push(AppRoutes.restaurantsWith(category: promo.categoryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: AppDurations.slow,
          child: _loading
              ? const HomeShimmer(key: ValueKey('shimmer'))
              : RefreshIndicator(
                  key: const ValueKey('content'),
                  color: AppColors.primary,
                  onRefresh: () => Future.delayed(const Duration(seconds: 1)),
                  child: _buildContent(context),
                ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final popular = CatalogMockData.popularRestaurants;
    final nearby = CatalogMockData.nearbyRestaurants;
    final cardWidth = math.min(context.screenSize.width * 0.68, 300.0);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        const SliverToBoxAdapter(child: HomeHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.lg,
              AppSizes.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                        Text(
                          'Bonjour ${ProfileController.instance.user.firstName} 👋',
                          style: context.text.bodyLarge?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Qu'est-ce qui vous ferait plaisir aujourd'hui ?",
                          style: context.text.headlineSmall,
                        ),
                        const SizedBox(height: AppSizes.md),
                        const _SearchBarButton(),
                        const SizedBox(height: AppSizes.lg),
                        const _ServicesRow(),
                      ]
                      .animate(interval: 70.ms)
                      .fadeIn(duration: 450.ms)
                      .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        ),
        // Catégories
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.lg),
            child: Column(
              children: [
                const SectionHeader(title: 'Catégories'),
                const SizedBox(height: AppSizes.md),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePadding,
                    ),
                    itemCount: CatalogMockData.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final category = CatalogMockData.categories[i];
                      return CategoryItem(
                            category: category,
                            onTap: () => context.push(
                              AppRoutes.restaurantsWith(category: category.id),
                            ),
                          )
                          .animate(delay: (60 * i).ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(
                            begin: 0.3,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Promotions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.md),
            child: PromoCarousel(
              promotions: CatalogMockData.promotions,
              onTap: _openPromotion,
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
          ),
        ),
        // Populaires
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.lg),
            child: SectionHeader(
              title: 'Populaires 🔥',
              onAction: () =>
                  context.push(AppRoutes.restaurantsWith(filter: 'popular')),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            // Hauteur suivant la taille de texte choisie par l'utilisateur.
            height: 196 + MediaQuery.textScalerOf(context).scale(84),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.md,
              ),
              itemCount: popular.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
              // Align : la carte garde sa hauteur naturelle.
              itemBuilder: (context, i) =>
                  Align(
                        alignment: Alignment.topCenter,
                        child: RestaurantCard(
                          restaurant: popular[i],
                          heroOrigin: 'popular',
                          width: cardWidth,
                        ),
                      )
                      .animate(delay: (80 * i).ms)
                      .fadeIn(duration: 450.ms)
                      .slideX(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        ),
        // Près de chez vous
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSizes.sm,
              bottom: AppSizes.md,
            ),
            child: SectionHeader(
              title: 'Près de chez vous',
              onAction: () =>
                  context.push(AppRoutes.restaurantsWith(filter: 'nearby')),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          sliver: SliverList.separated(
            itemCount: math.min(nearby.length, 6),
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
            itemBuilder: (context, i) =>
                RestaurantTile(restaurant: nearby[i], heroOrigin: 'nearby')
                    .animate(delay: (70 * math.min(i, 5)).ms)
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
      ],
    );
  }
}

/// Fausse barre de recherche : ouvre l'écran Recherche.
class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push(AppRoutes.search),
      scale: 0.98,
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(left: AppSizes.md, right: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: context.palette.softShadow,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: context.palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rechercher un plat, un restaurant…',
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Pressable(
              onTap: () => context.push(AppRoutes.restaurants),
              scale: 0.88,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les trois services SuperFaster : restaurants, courses, colis.
class _ServicesRow extends StatelessWidget {
  const _ServicesRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ServiceCard(
            emoji: '🍔',
            title: 'Restaurants',
            subtitle: '+120 adresses',
            color: AppColors.primary,
            onTap: () => context.push(AppRoutes.restaurants),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ServiceCard(
            emoji: '🛒',
            title: 'Courses',
            subtitle: 'En 30 min',
            color: AppColors.success,
            onTap: () =>
                context.push(AppRoutes.restaurantsWith(category: 'courses')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ServiceCard(
            emoji: '📦',
            title: 'Colis',
            subtitle: 'Express',
            color: const Color(0xFF6366F1),
            onTap: () => context.push(AppRoutes.parcel),
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const Spacer(),
            // Réduit légèrement le titre sur les écrans étroits.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title, style: context.text.titleSmall, maxLines: 1),
            ),
            Text(
              subtitle,
              style: context.text.labelSmall?.copyWith(color: color),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
