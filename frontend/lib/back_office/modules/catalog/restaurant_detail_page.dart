import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import '../communication/communication_controllers.dart';
import '../orders/orders_controller.dart';
import '../users/users_controller.dart';
import 'catalog_controllers.dart';
import 'restaurant_form.dart';
import 'restaurants_page.dart';

/// Fiche d'un restaurant (admin) : statut, chiffres, menu et avis.
class RestaurantDetailPage extends ConsumerWidget {
  const RestaurantDetailPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantsControllerProvider);
    final parent = BreadcrumbItem(
      'Restaurants',
      onTap: () => context.go(BackRoutes.restaurants),
    );
    final restaurant = restaurants.value
        ?.where((r) => r.id == restaurantId)
        .firstOrNull;
    if (restaurant == null) {
      return BoPage(
        title: restaurants.isLoading ? 'Chargement…' : 'Restaurant introuvable',
        parent: parent,
        children: [
          if (restaurants.isLoading)
            const ShimmerScope(
              child: SkeletonBox(height: 260, radius: AppSizes.radiusLg),
            )
          else
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.storefront_rounded,
                title: 'Restaurant introuvable',
                message: 'Ce restaurant a peut-être été supprimé.',
                actionLabel: 'Retour à la liste',
                onAction: () => context.go(BackRoutes.restaurants),
              ),
            ),
        ],
      );
    }

    final r = restaurant;
    return BoPage(
      title: r.name,
      parent: parent,
      actions: [
        OutlinedButton.icon(
          onPressed: () => openRestaurantForm(context, restaurant: r),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Modifier'),
        ),
        ...switch (r.status) {
          RestaurantStatus.pending => [
            OutlinedButton.icon(
              onPressed: () => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.rejected,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: AppColors.error,
              ),
              icon: const Icon(Icons.block_rounded),
              label: const Text('Refuser'),
            ),
            FilledButton.icon(
              onPressed: () => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.approved,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: AppColors.success,
              ),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Valider'),
            ),
          ],
          RestaurantStatus.approved => [
            OutlinedButton.icon(
              onPressed: () => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.suspended,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: AppColors.error,
              ),
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Suspendre'),
            ),
          ],
          _ => [
            FilledButton.icon(
              onPressed: () => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.approved,
              ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Réactiver'),
            ),
          ],
        },
      ],
      children: [RestaurantOverview(restaurant: r, showOwner: true)],
    );
  }
}

/// Vue d'ensemble d'un restaurant (fiche admin et « Mon restaurant ») :
/// bannière, indicateurs, informations, menu et derniers avis.
class RestaurantOverview extends ConsumerWidget {
  const RestaurantOverview({
    super.key,
    required this.restaurant,
    this.showOwner = false,
  });

  final Restaurant restaurant;
  final bool showOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = restaurant;
    final orders = (ref.watch(ordersControllerProvider).value ?? const [])
        .where((o) => o.restaurantId == r.id)
        .toList();
    final revenue = orders
        .where(
          (o) =>
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.refunded,
        )
        .fold<double>(0, (s, o) => s + o.total);
    final products = (ref.watch(productsControllerProvider).value ?? const [])
        .where((p) => p.restaurantId == r.id)
        .toList();
    final reviews = (ref.watch(reviewsControllerProvider).value ?? const [])
        .where((v) => v.restaurantId == r.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(restaurant: r),
        boGap,
        ResponsiveGrid(
          children: [
            StatCard(
              label: 'Commandes',
              value: orders.length,
              icon: Icons.receipt_long_rounded,
              caption:
                  '${orders.where((o) => o.status.isActive).length} en cours',
            ),
            StatCard(
              label: "Chiffre d'affaires",
              value: revenue,
              format: Formatters.priceShort,
              icon: Icons.euro_rounded,
              color: AppColors.success,
              caption: 'Hors annulations',
            ),
            StatCard(
              label: 'Note moyenne',
              value: r.rating,
              format: Formatters.rating,
              icon: Icons.star_rounded,
              color: AppColors.warning,
              caption: '${r.reviewCount} avis',
            ),
            StatCard(
              label: 'Produits',
              value: products.length,
              icon: Icons.fastfood_rounded,
              color: AppColors.info,
              caption:
                  '${products.where((p) => !p.isAvailable).length} en rupture',
            ),
          ],
        ),
        boGap,
        SplitRow(
          leftFlex: 2,
          rightFlex: 3,
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoCard(restaurant: r),
              if (showOwner) ...[boGap, _OwnerCard(restaurant: r)],
              boGap,
              _ReviewsCard(reviews: reviews),
            ],
          ),
          right: _MenuCard(restaurant: r, products: products),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(r.imageUrl, width: double.infinity, height: 200)
                .animate()
                .scaleXY(begin: 1.08, end: 1, duration: 900.ms),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: [
                      restaurantStatusChip(r.status),
                      _BannerTag(
                        icon: r.isOpen
                            ? Icons.door_front_door_rounded
                            : Icons.nightlight_round,
                        label: r.isOpen ? 'Ouvert' : 'Fermé',
                      ),
                      if (r.promo != null)
                        _BannerTag(
                          icon: Icons.local_offer_rounded,
                          label: r.promo!,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    r.name,
                    style: context.text.headlineSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    r.cuisine,
                    style: const TextStyle(color: Colors.white70),
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

class _BannerTag extends StatelessWidget {
  const _BannerTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return SectionCard(
      title: 'Informations',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(r.description, style: context.text.bodyMedium),
          const SizedBox(height: AppSizes.sm),
          infoText(Icons.place_outlined, 'Adresse', r.address),
          infoText(Icons.phone_outlined, 'Téléphone', r.phone),
          infoText(
            Icons.timer_outlined,
            'Livraison',
            '${r.deliveryTimeLabel} • ${r.deliveryFee == 0 ? 'offerte' : Formatters.price(r.deliveryFee)}',
          ),
          infoText(
            Icons.shopping_basket_outlined,
            'Commande minimum',
            Formatters.price(r.minOrder),
          ),
          infoText(
            Icons.event_rounded,
            'Partenaire depuis',
            Formatters.date(r.createdAt),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends ConsumerWidget {
  const _OwnerCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = (ref.watch(usersControllerProvider).value ?? const [])
        .where((u) => u.id == restaurant.ownerId)
        .firstOrNull;
    return SectionCard(
      title: 'Responsable',
      icon: Icons.person_outline_rounded,
      child: owner == null
          ? Text(
              'Aucun compte associé.',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            )
          : ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  owner.initials,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              title: Text(owner.fullName),
              subtitle: Text(owner.email),
              trailing: userStatusChip(owner.status),
              onTap: () => context.go(BackRoutes.user(owner.id)),
            ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final latest = reviews.take(3).toList();
    return SectionCard(
      title: 'Derniers avis',
      icon: Icons.star_outline_rounded,
      trailing: TextButton(
        onPressed: () => context.go(BackRoutes.reviews),
        child: const Text('Tout voir'),
      ),
      child: latest.isEmpty
          ? Text(
              'Aucun avis pour le moment.',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            )
          : DividedColumn(
              children: [
                for (final review in latest)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                review.userName,
                                style: context.text.titleSmall,
                              ),
                            ),
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.comment,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Menu du restaurant par onglet, avec l'interrupteur disponible / rupture.
class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.restaurant, required this.products});

  final Restaurant restaurant;
  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = {
      ...restaurant.menuSections,
      for (final p in products) p.section,
    }.where((s) => products.any((p) => p.section == s));

    return SectionCard(
      title: 'Menu',
      icon: Icons.restaurant_menu_rounded,
      subtitle: '${products.length} produits',
      trailing: TextButton.icon(
        onPressed: () => context.go(BackRoutes.products),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Gérer'),
      ),
      child: products.isEmpty
          ? const EmptyState(
              compact: true,
              icon: Icons.no_food_rounded,
              title: 'Menu vide',
              message: 'Ajoutez des produits depuis la page Produits.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      section.toUpperCase(),
                      style: context.text.labelSmall?.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final p in products.where((p) => p.section == section))
                    _MenuRow(product: p),
                ],
              ],
            ),
    );
  }
}

class _MenuRow extends ConsumerWidget {
  const _MenuRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Opacity(
            opacity: p.isAvailable ? 1 : 0.4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppNetworkImage(p.imageUrl, width: 48, height: 48),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    decoration: p.isAvailable
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  p.isAvailable
                      ? Formatters.price(p.price)
                      : '${Formatters.price(p.price)} • en rupture',
                  style: context.text.bodySmall?.copyWith(
                    color: p.isAvailable
                        ? context.palette.textSecondary
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: p.isAvailable,
            onChanged: (on) async {
              try {
                await ref
                    .read(productsControllerProvider.notifier)
                    .setAvailability(p, on);
              } catch (error) {
                if (context.mounted) AppSnackbar.error(context, error);
              }
            },
          ),
        ],
      ),
    );
  }
}
