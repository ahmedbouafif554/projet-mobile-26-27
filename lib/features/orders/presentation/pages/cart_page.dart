import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/animated_price.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../catalog/data/catalog_mock_data.dart';
import '../../models/cart_item.dart';
import '../controllers/cart_controller.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/price_summary.dart';
import '../widgets/promo_code_field.dart';

/// Panier : quantités modifiables, glisser pour supprimer,
/// code promo et total détaillé.
class CartPage extends StatelessWidget {
  const CartPage({super.key});

  CartController get _cart => CartController.instance;

  /// Supprime une ligne en proposant de l'annuler.
  void _removeWithUndo(BuildContext context, CartItem item) {
    final index = _cart.remove(item.key);
    AppSnackbar.show(
      context,
      '${item.product.name} retiré du panier',
      icon: Icons.delete_outline_rounded,
      actionLabel: 'Annuler',
      onAction: () => _cart.restore(item, index),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text(
          'Tous les articles seront retirés de votre panier.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirmed == true) _cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        final items = _cart.items;

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 68,
            leading: const Center(child: AppBackButton()),
            title: const Text('Mon panier'),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmClear(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Vider'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: AnimatedSwitcher(
            duration: AppDurations.slow,
            child: items.isEmpty
                ? EmptyState(
                    key: const ValueKey('empty'),
                    lottieAsset: AppAssets.lottieEmptyCart,
                    title: 'Votre panier est vide',
                    message:
                        'Ajoutez de délicieux plats pour commencer votre commande.',
                    actionLabel: 'Découvrir les restaurants',
                    onAction: () => context.go(AppRoutes.home),
                  )
                : ListView(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.sm,
                      AppSizes.pagePadding,
                      AppSizes.xl,
                    ),
                    children: [
                      _RestaurantBanner(
                        restaurantId: items.first.product.restaurantId,
                      ),
                      const SizedBox(height: AppSizes.md),
                      for (final (i, item) in items.indexed)
                        Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Dismissible(
                                key: ValueKey(item.key),
                                direction: DismissDirection.endToStart,
                                background: const _DeleteBackground(),
                                onDismissed: (_) =>
                                    _removeWithUndo(context, item),
                                child: CartItemTile(
                                  item: item,
                                  onQuantityChanged: (q) =>
                                      _cart.updateQuantity(item.key, q),
                                  onRemove: () =>
                                      _removeWithUndo(context, item),
                                ),
                              ),
                            )
                            .animate(
                              key: ValueKey('anim-${item.key}'),
                              delay: (60 * i).ms,
                            )
                            .fadeIn(duration: 350.ms)
                            .slideX(begin: 0.1, end: 0),
                      Row(
                        children: [
                          Icon(
                            Icons.swipe_left_rounded,
                            size: 16,
                            color: context.palette.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Glissez un article vers la gauche pour le supprimer',
                              style: context.text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.lg),
                      const PromoCodeField(),
                      const SizedBox(height: AppSizes.lg),
                      PriceSummary(
                        subtotal: _cart.subtotal,
                        deliveryFee: _cart.deliveryFee,
                        serviceFee: _cart.serviceFee,
                        discount: _cart.discount,
                        total: _cart.total,
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: AnimatedSize(
            duration: AppDurations.medium,
            child: items.isEmpty
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
                      child: PrimaryButton(
                        label: 'Commander',
                        trailing: AnimatedPrice(_cart.total),
                        onPressed: () => context.push(AppRoutes.checkout),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Rappel du restaurant d'où proviennent les articles.
class _RestaurantBanner extends StatelessWidget {
  const _RestaurantBanner({required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    final r = CatalogMockData.restaurantById(restaurantId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(r.name, style: context.text.titleSmall)),
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            r.deliveryTimeLabel,
            style: context.text.labelMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Fond rouge révélé pendant le glissement d'un article.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Supprimer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          SizedBox(width: 8),
          Icon(Icons.delete_rounded, color: Colors.white),
        ],
      ),
    );
  }
}
