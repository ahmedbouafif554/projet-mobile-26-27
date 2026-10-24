import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../../core/widgets/section_header.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/mock/mock_images.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../auth/providers/addresses_controller.dart';
import '../../../communication/providers/communication_providers.dart';
import '../../providers/catalog_providers.dart';

/// Accueil du client (onglet Explorer) : adresse de livraison, recherche,
/// offres, catégories, restaurants populaires et liste complète.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(restaurantsProvider)
      ..invalidate(categoriesProvider);
    await ref.read(restaurantsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              const SliverToBoxAdapter(child: _SearchBar()),
              const SliverToBoxAdapter(child: _PromoCarousel()),
              const SliverToBoxAdapter(child: _Categories()),
              ...restaurants.when(
                loading: () => [
                  const SliverToBoxAdapter(child: _RestaurantsSkeleton()),
                ],
                error: (e, _) => [
                  SliverToBoxAdapter(
                    child: ErrorView(
                      message: '$e',
                      onRetry: () => ref.invalidate(restaurantsProvider),
                    ),
                  ),
                ],
                data: (list) => _restaurantSections(context, list),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _restaurantSections(BuildContext context, List<Restaurant> all) {
    final popular = all.where((r) => r.isPopular && r.isOpen).toList();
    final offers = all.where((r) => r.promo != null).toList();
    final sorted = const RestaurantFilter().apply(all);
    void open(Restaurant r) => context.push(FrontRoutes.restaurant(r.id));

    Widget carousel(List<Restaurant> list) => SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.sm,
          AppSizes.pagePadding,
          AppSizes.md,
        ),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
        itemBuilder: (_, i) => RestaurantCard(
          restaurant: list[i],
          width: 250,
          imageHeight: 140,
          onTap: () => open(list[i]),
        ).animate(delay: (60 * i).ms).fadeIn().slideX(begin: 0.1, end: 0),
      ),
    );

    return [
      if (popular.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Populaires 🔥',
            onAction: () => context.push(FrontRoutes.restaurants),
          ),
        ),
        SliverToBoxAdapter(child: carousel(popular)),
      ],
      if (offers.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader(title: 'Offres du moment')),
        SliverToBoxAdapter(child: carousel(offers)),
      ],
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Tous les restaurants',
          actionLabel: 'Filtrer',
          onAction: () => context.push(FrontRoutes.restaurants),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.sm,
          AppSizes.pagePadding,
          0,
        ),
        sliver: SliverList.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
          itemBuilder: (_, i) => RestaurantCard(
            restaurant: sorted[i],
            onTap: () => open(sorted[i]),
          ).animate(delay: (40 * (i % 6)).ms).fadeIn().slideY(begin: 0.06, end: 0),
        ),
      ),
    ];
  }
}

/// Bonjour + adresse de livraison + cloche des notifications.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).user;
    final address = ref.watch(addressesProvider).value?.firstOrNull;
    final unread = ref.watch(
      notificationsProvider.select(
        (n) => n.value?.where((x) => !x.isRead).length ?? 0,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => context.push(FrontRoutes.addresses),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour ${user?.firstName ?? ''} 👋',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          address == null
                              ? 'Ajouter une adresse'
                              : '${address.label} • ${address.street}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.badge,
            label: Text('$unread'),
            offset: const Offset(-4, 4),
            child: CircleIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              elevated: true,
              onTap: () => context.push(FrontRoutes.notifications),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Faux champ : ouvre l'onglet Recherche.
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: Pressable(
        onTap: () => context.go(FrontRoutes.search),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: context.palette.softShadow,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: context.palette.textSecondary),
              const SizedBox(width: AppSizes.sm + 4),
              Expanded(
                child: Text(
                  'Restaurants, plats, cuisines…',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 300.ms);
  }
}

/// Bannières d'offres qui défilent toutes les 4 secondes.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _page = 0;

  static final _promos = [
    (
      '-10 % sur votre commande',
      'Code SUPER10 au moment de payer',
      unsplash('1568901346375-23c9450c58cd'),
      'r1',
    ),
    (
      'Livraison offerte',
      'Code LIVRAISON, sans minimum',
      unsplash('1579871494447-9811cf80d66c'),
      'r3',
    ),
    (
      '5 € offerts dès 15 €',
      'Code BIENVENUE pour votre 1re commande',
      unsplash('1512621776951-a57141f2eefd'),
      'r4',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _promos.length,
        duration: AppDurations.slow,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final (title, subtitle, image, restaurantId) = _promos[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Pressable(
                  onTap: () =>
                      context.push(FrontRoutes.restaurant(restaurantId)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(image),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xE6FF5A1F), Color(0x00FF5A1F)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 210,
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleLarge?.copyWith(
                                    color: Colors.white,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 210,
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'J’en profite',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _promos.length; i++)
              AnimatedContainer(
                duration: AppDurations.fast,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : context.palette.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 120.ms, duration: 400.ms);
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    if (categories.isEmpty) return const SizedBox(height: AppSizes.lg);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.lg, bottom: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Catégories'),
          const SizedBox(height: AppSizes.sm + 4),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding,
              ),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => CategoryBubble(
                category: categories[i],
                onTap: () {
                  ref
                      .read(restaurantFilterProvider.notifier)
                      .update(
                        ref
                            .read(restaurantFilterProvider)
                            .copyWith(categoryId: categories[i].id),
                      );
                  context.push(FrontRoutes.restaurants);
                },
              ).animate(delay: (40 * i).ms).fadeIn().scaleXY(begin: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantsSkeleton extends StatelessWidget {
  const _RestaurantsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSizes.md),
                child: SkeletonBox(height: 230, radius: AppSizes.radiusLg),
              ),
          ],
        ),
      ),
    );
  }
}
