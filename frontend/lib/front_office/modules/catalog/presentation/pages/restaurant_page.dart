import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../orders/providers/cart_controller.dart';
import '../../providers/catalog_providers.dart';
import '../widgets/product_sheet.dart';

/// Fiche d'un restaurant : photo, infos de livraison, menu par onglets
/// (le choix d'un onglet fait défiler jusqu'à la section) et barre du panier.
class RestaurantPage extends ConsumerWidget {
  const RestaurantPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider(restaurantId));
    return Scaffold(
      body: AsyncValueView(
        value: restaurant,
        onRetry: () => ref.invalidate(restaurantProvider(restaurantId)),
        loading: const ShimmerScope(
          child: Column(
            children: [
              SkeletonBox(height: 260, radius: 0),
              SizedBox(height: AppSizes.md),
              Padding(
                padding: EdgeInsets.all(AppSizes.pagePadding),
                child: SkeletonBox(height: 120, radius: AppSizes.radiusLg),
              ),
            ],
          ),
        ),
        data: (r) => _RestaurantView(restaurant: r),
      ),
    );
  }
}

class _RestaurantView extends ConsumerStatefulWidget {
  const _RestaurantView({required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<_RestaurantView> createState() => _RestaurantViewState();
}

class _RestaurantViewState extends ConsumerState<_RestaurantView> {
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _activeSection;

  GlobalKey _keyFor(String section) =>
      _sectionKeys.putIfAbsent(section, GlobalKey.new);

  void _scrollTo(String section) {
    setState(() => _activeSection = section);
    final target = _sectionKeys[section]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final products = ref.watch(restaurantProductsProvider(r.id));
    final cart = ref.watch(cartProvider).value ?? const <CartItem>[];
    final cartHere = cart.where((i) => i.product.restaurantId == r.id).toList();
    final reviewsPath = '${GoRouterState.of(context).uri.path}/reviews';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              stretch: true,
              backgroundColor: context.colors.surface,
              leading: const Padding(
                padding: EdgeInsets.all(6),
                child: AppBackButton(
                  elevated: true,
                  fallbackRoute: FrontRoutes.explore,
                ),
              ),
              actions: [
                FavoriteButton(restaurantId: r.id, size: 40),
                const SizedBox(width: 8),
                CircleIconButton(
                  icon: Icons.ios_share_rounded,
                  elevated: true,
                  tooltip: 'Partager',
                  onTap: () => AppSnackbar.info(
                    context,
                    'Lien de ${r.name} copié (démo).',
                  ),
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                stretchModes: const [StretchMode.zoomBackground],
                background: AppNetworkImage(r.imageUrl),
              ),
            ),
            SliverToBoxAdapter(
              child: _InfoCard(
                restaurant: r,
                onReviews: () => context.push(reviewsPath),
              ),
            ),
            ...products.when(
              loading: () => [
                const SliverToBoxAdapter(
                  child: ShimmerScope(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.pagePadding),
                      child: SkeletonBox(height: 300, radius: AppSizes.radiusLg),
                    ),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(child: ErrorView(message: '$e')),
              ],
              data: (list) => _menu(list, cartHere),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: cartHere.isEmpty ? AppSizes.xl : 110),
            ),
          ],
        ),
        if (cartHere.isNotEmpty)
          Positioned(
            left: AppSizes.pagePadding,
            right: AppSizes.pagePadding,
            bottom: AppSizes.md,
            child: _CartBar(items: cartHere, restaurant: r),
          ),
      ],
    );
  }

  List<Widget> _menu(List<Product> products, List<CartItem> cart) {
    final sections = [
      for (final s in {
        ...widget.restaurant.menuSections,
        for (final p in products) p.section,
      })
        if (products.any((p) => p.section == s)) s,
    ];
    int inCart(Product p) => cart
        .where((i) => i.product.id == p.id)
        .fold(0, (sum, i) => sum + i.quantity);
    final popular = products.where((p) => p.isPopular && p.isAvailable).toList();

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _SectionTabs(
          sections: sections,
          active: _activeSection ?? sections.firstOrNull,
          onSelected: _scrollTo,
        ),
      ),
      if (popular.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.pagePadding,
                  ),
                  child: Text('Les plus commandés', style: context.text.titleLarge),
                ),
                SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      12,
                      AppSizes.pagePadding,
                      16,
                    ),
                    itemCount: popular.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSizes.sm + 4),
                    itemBuilder: (context, i) => _PopularCard(
                      product: popular[i],
                      onTap: () => showProductSheet(context, popular[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      for (final section in sections)
        SliverToBoxAdapter(
          key: _keyFor(section),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.md,
              AppSizes.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(section, style: context.text.titleLarge),
                for (final (i, p) in products
                    .where((p) => p.section == section)
                    .indexed) ...[
                  if (i > 0) Divider(height: 1, color: context.palette.border),
                  ProductTile(
                    product: p,
                    quantityInCart: inCart(p),
                    onTap: () => showProductSheet(context, p),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.restaurant, required this.onReviews});

  final Restaurant restaurant;
  final VoidCallback onReviews;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 4),
          Text(value, style: context.text.titleSmall, maxLines: 1),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(r.name, style: context.text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            r.cuisine,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(r.description, style: context.text.bodyMedium),
          if (!r.isOpen) ...[
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.nightlight_round, color: AppColors.error),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fermé pour le moment : vous pouvez consulter le menu.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (r.promo != null) ...[
            const SizedBox(height: AppSizes.md),
            Align(
              alignment: Alignment.centerLeft,
              child: PromoBadge(label: r.promo!),
            ),
          ],
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              boxShadow: context.palette.softShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: onReviews,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.reviewCount == 0
                              ? 'Nouveau'
                              : Formatters.rating(r.rating),
                          style: context.text.titleSmall,
                        ),
                        Text(
                          '${Formatters.compact(r.reviewCount)} avis ›',
                          style: context.text.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                stat(Icons.schedule_rounded, r.deliveryTimeLabel, 'Livraison'),
                stat(
                  Icons.delivery_dining_rounded,
                  r.deliveryFee == 0 ? 'Offerte' : Formatters.price(r.deliveryFee),
                  'Frais',
                ),
                stat(
                  Icons.shopping_basket_outlined,
                  Formatters.priceShort(r.minOrder),
                  'Minimum',
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }
}

/// Onglets du menu, épinglés sous la barre du haut.
class _SectionTabs extends SliverPersistentHeaderDelegate {
  _SectionTabs({
    required this.sections,
    required this.active,
    required this.onSelected,
  });

  final List<String> sections;
  final String? active;
  final ValueChanged<String> onSelected;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: context.theme.scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: 10,
        ),
        children: [
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.sm),
              child: SelectableChip(
                label: s,
                selected: s == active,
                onTap: () => onSelected(s),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionTabs old) =>
      old.active != active || old.sections != sections;
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: context.palette.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppNetworkImage(product.imageUrl, height: 90, width: 140),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.price(product.price),
                    style: context.text.labelLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre flottante « Voir le panier ».
class _CartBar extends StatelessWidget {
  const _CartBar({required this.items, required this.restaurant});

  final List<CartItem> items;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final count = items.fold(0, (s, i) => s + i.quantity);
    final total = items.fold<double>(0, (s, i) => s + i.totalPrice);
    return Pressable(
      onTap: () => context.go(FrontRoutes.cart),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Voir le panier',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              Formatters.price(total),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1.5, end: 0, curve: Curves.easeOutBack);
  }
}
