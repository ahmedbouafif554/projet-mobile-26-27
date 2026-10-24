import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../catalog/providers/catalog_providers.dart';
import '../../providers/cart_controller.dart';
import '../widgets/order_widgets.dart';

/// Panier (onglet) : articles du restaurant, quantités, suppression par
/// balayage (avec « Annuler »), récapitulatif et passage à la commande.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Vider le panier ?',
      message: 'Tous les articles seront retirés.',
      confirmLabel: 'Vider',
      icon: Icons.remove_shopping_cart_outlined,
    );
    if (confirmed) await ref.read(cartProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final items = cart.value ?? const <CartItem>[];
    final restaurantId = items.firstOrNull?.product.restaurantId;
    final restaurant = restaurantId == null
        ? null
        : ref.watch(restaurantProvider(restaurantId)).value;
    final totals = CartTotals.of(items, restaurant);
    final belowMinimum =
        restaurant != null && totals.subtotal < restaurant.minOrder;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.sm,
                AppSizes.sm,
              ),
              child: Row(
                children: [
                  const Expanded(child: PageTitle('Mon panier')),
                  if (items.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _clear(context, ref),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Vider'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cart.isLoading && cart.value == null
                  ? const ShimmerScope(
                      child: Padding(
                        padding: EdgeInsets.all(AppSizes.pagePadding),
                        child: SkeletonBox(height: 260, radius: AppSizes.radiusLg),
                      ),
                    )
                  : items.isEmpty
                  ? EmptyState(
                      lottieAsset: AppAssets.lottieEmpty,
                      title: 'Votre panier est vide',
                      message:
                          'Parcourez les restaurants et ajoutez vos plats préférés.',
                      actionLabel: 'Explorer les restaurants',
                      onAction: () => context.go(FrontRoutes.explore),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.pagePadding,
                        AppSizes.sm,
                        AppSizes.pagePadding,
                        AppSizes.lg,
                      ),
                      children: [
                        if (restaurant != null)
                          _RestaurantHeader(restaurant: restaurant),
                        const SizedBox(height: AppSizes.md),
                        for (final (i, item) in items.indexed)
                          _CartLine(key: ValueKey(item.id), item: item)
                              .animate(delay: (40 * i).ms)
                              .fadeIn()
                              .slideX(begin: 0.05, end: 0),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: restaurant == null
                                ? null
                                : () => context.go(
                                    FrontRoutes.restaurant(restaurant.id),
                                  ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Ajouter des articles'),
                          ),
                        ),
                        const SizedBox(height: AppSizes.sm),
                        TotalsCard(totals: totals),
                        if (belowMinimum) ...[
                          const SizedBox(height: AppSizes.md),
                          _MinimumNotice(
                            missing: restaurant.minOrder - totals.subtotal,
                          ),
                        ],
                      ],
                    ),
            ),
            if (items.isNotEmpty)
              _CheckoutBar(
                total: totals.total,
                enabled: !belowMinimum && (restaurant?.isOpen ?? true),
                closed: restaurant != null && !restaurant.isOpen,
              ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: () => context.go(FrontRoutes.restaurant(restaurant.id)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: AppNetworkImage(restaurant.imageUrl, width: 52, height: 52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name, style: context.text.titleMedium),
                Text(
                  'Livraison ${restaurant.deliveryTimeLabel}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm + 4),
      child: Dismissible(
        key: ValueKey('dismiss-${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        onDismissed: (_) async {
          await cart.remove(item);
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            '${item.product.name} retiré du panier',
            icon: Icons.delete_outline_rounded,
            actionLabel: 'Annuler',
            onAction: () => cart.restore(item),
          );
        },
        child: SurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: AppNetworkImage(
                  item.product.imageUrl,
                  width: 70,
                  height: 70,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    if (item.options.isNotEmpty)
                      Text(
                        item.optionsLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    if (item.note != null)
                      Text(
                        '« ${item.note} »',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.price(item.totalPrice),
                            style: context.text.titleSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        QuantityStepper(
                          value: item.quantity,
                          min: 0,
                          compact: true,
                          onChanged: (q) => cart.setQuantity(item, q),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimumNotice extends StatelessWidget {
  const _MinimumNotice({required this.missing});

  final double missing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Encore ${Formatters.price(missing)} pour atteindre le minimum de commande.',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    ).animate().shakeX(hz: 3, amount: 3);
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.total,
    required this.enabled,
    required this.closed,
  });

  final double total;
  final bool enabled;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm + 4,
        AppSizes.pagePadding,
        AppSizes.sm + 4,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: PrimaryButton(
        label: closed ? 'Restaurant fermé' : 'Commander',
        icon: Icons.lock_outline_rounded,
        onPressed: enabled ? () => context.push(FrontRoutes.checkout) : null,
        trailing: Text(
          Formatters.price(total),
          style: context.text.titleMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
