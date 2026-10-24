import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_price.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../communication/communication_routes.dart';
import '../../../orders/presentation/controllers/cart_controller.dart';
import '../../data/catalog_mock_data.dart';
import '../../models/product.dart';
import '../../models/restaurant.dart';
import '../widgets/favorite_button.dart';
import '../widgets/product_tile.dart';

/// Page restaurant : grande image qui se réduit au défilement (SliverAppBar),
/// informations, onglets du menu et liste des produits.
class RestaurantPage extends StatefulWidget {
  const RestaurantPage({
    super.key,
    required this.restaurantId,
    required this.heroOrigin,
  });

  final String restaurantId;
  final String heroOrigin;

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage>
    with SingleTickerProviderStateMixin {
  late final Restaurant _restaurant = CatalogMockData.restaurantById(
    widget.restaurantId,
  );
  late final List<Product> _products = CatalogMockData.productsOf(
    _restaurant.id,
  );
  late final List<String> _sections = CatalogMockData.menuSectionsOf(
    _restaurant,
  );
  late final TabController _tabs = TabController(
    length: _sections.length,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Product> get _visibleProducts {
    final section = _sections[_tabs.index];
    return section == 'Populaires'
        ? _products.where((p) => p.isPopular).toList()
        : _products.where((p) => p.section == section).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = _restaurant;
    final products = _visibleProducts;

    return Scaffold(
      // Le contenu défile sous la barre « Voir le panier ».
      extendBody: true,
      // En bottomNavigationBar, les snackbars s'affichent au-dessus de la barre.
      bottomNavigationBar: const _ViewCartBar(),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            automaticallyImplyLeading: false,
            backgroundColor: context.theme.scaffoldBackgroundColor,
            leadingWidth: 68,
            leading: const Center(child: AppBackButton(elevated: true)),
            actions: [
              FavoriteButton(restaurantId: r.id, size: 44),
              const SizedBox(width: 10),
              CircleIconButton(
                icon: Icons.ios_share_rounded,
                elevated: true,
                tooltip: 'Partager',
                onTap: () =>
                    AppSnackbar.success(context, 'Lien du restaurant copié'),
              ),
              const SizedBox(width: AppSizes.md),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                // Le titre n'apparaît que lorsque la barre est réduite.
                final topPadding = MediaQuery.paddingOf(context).top;
                final collapsed =
                    constraints.maxHeight <= kToolbarHeight + topPadding + 24;
                return FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  centerTitle: true,
                  title: AnimatedOpacity(
                    opacity: collapsed ? 1 : 0,
                    duration: AppDurations.fast,
                    child: Text(r.name, style: context.text.titleMedium),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: HeroTags.restaurant(r.id, widget.heroOrigin),
                        child: AppNetworkImage(r.imageUrl),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x66000000),
                              Colors.transparent,
                              Color(0x55000000),
                            ],
                            stops: [0, 0.4, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: _RestaurantInfo(restaurant: r)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _MenuTabsDelegate(
              background: context.theme.scaffoldBackgroundColor,
              tabBar: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                labelColor: Colors.white,
                splashBorderRadius: BorderRadius.circular(AppSizes.radiusSm),
                tabs: [for (final s in _sections) Tab(text: s, height: 40)],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.md,
              AppSizes.pagePadding,
              120,
            ),
            sliver: SliverList.separated(
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  ProductTile(product: products[i], heroOrigin: 'menu')
                      // Rejoue la cascade à chaque changement d'onglet.
                      .animate(
                        key: ValueKey('${_tabs.index}-${products[i].id}'),
                      )
                      .fadeIn(duration: 350.ms, delay: (60 * i).ms)
                      .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc d'informations sous l'image.
class _RestaurantInfo extends StatelessWidget {
  const _RestaurantInfo({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.lg,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            [
                  Text(r.name, style: context.text.headlineMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        r.cuisine,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: context.palette.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        Formatters.distance(r.distanceKm),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      Expanded(
                        // Ouvre les avis clients (module 5).
                        child: Pressable(
                          onTap: () => context.push(
                            CommunicationRoutes.restaurantReviews(r.id),
                          ),
                          child: _StatBox(
                            icon: Icons.star_rounded,
                            iconColor: context.palette.warning,
                            value: r.rating
                                .toStringAsFixed(1)
                                .replaceAll('.', ','),
                            label: 'Voir les avis ›',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.schedule_rounded,
                          iconColor: AppColors.info,
                          value: r.deliveryTimeLabel,
                          label: 'Livraison',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.delivery_dining_rounded,
                          iconColor: AppColors.success,
                          value: r.hasFreeDelivery
                              ? 'Offerte'
                              : Formatters.price(r.deliveryFee),
                          label: 'Frais',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    r.description,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  if (r.promo != null) ...[
                    const SizedBox(height: AppSizes.md),
                    Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_offer_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Offre en cours : ${r.promo} sur une sélection de produits',
                                  style: context.text.labelLarge?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        // Reflet qui traverse la bannière toutes les ~3 secondes.
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          delay: 1800.ms,
                          duration: 1200.ms,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                  ],
                ]
                .animate(interval: 60.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: context.text.titleSmall),
          ),
          Text(label, style: context.text.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

/// Onglets du menu épinglés sous la barre d'application.
class _MenuTabsDelegate extends SliverPersistentHeaderDelegate {
  _MenuTabsDelegate({required this.tabBar, required this.background});

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      alignment: Alignment.center,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _MenuTabsDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.background != background;
}

/// Barre « Voir le panier » qui glisse depuis le bas dès qu'il y a un article
/// (et se replie quand le panier est vide).
class _ViewCartBar extends StatelessWidget {
  const _ViewCartBar();

  @override
  Widget build(BuildContext context) {
    final cart = CartController.instance;

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        return AnimatedSize(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: cart.isEmpty
              ? const SizedBox(width: double.infinity)
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.sm,
                      AppSizes.pagePadding,
                      AppSizes.md,
                    ),
                    child:
                        Pressable(
                              onTap: () => context.push(AppRoutes.cart),
                              haptic: true,
                              child: Container(
                                height: 60,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusLg,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusSm,
                                        ),
                                      ),
                                      child:
                                          Text(
                                                '${cart.itemCount}',
                                                style: context.text.titleSmall
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                    ),
                                              )
                                              .animate(
                                                key: ValueKey(cart.itemCount),
                                              )
                                              .scaleXY(
                                                begin: 0.4,
                                                end: 1,
                                                duration: 500.ms,
                                                curve: Curves.elasticOut,
                                              ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Voir le panier',
                                        style: context.text.titleMedium
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                    AnimatedPrice(
                                      cart.subtotal,
                                      style: context.text.titleMedium?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            // Entrée : glisse depuis le bas avec un léger rebond.
                            .animate()
                            .slideY(
                              begin: 1.2,
                              end: 0,
                              duration: AppDurations.slow,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(duration: AppDurations.medium),
                  ),
                ),
        );
      },
    );
  }
}
