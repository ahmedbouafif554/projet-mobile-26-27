import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../orders/models/cart_item.dart';
import '../../../orders/presentation/controllers/cart_controller.dart';
import '../../models/product.dart';

/// Ligne de menu : description à gauche, photo (Hero) à droite
/// et bouton d'ajout rapide au panier.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.heroOrigin,
  });

  final Product product;
  final String heroOrigin;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final imageSize = context.isSmallScreen ? 86.0 : 100.0;

    return Pressable(
      onTap: () =>
          context.push(AppRoutes.productDetail(p.id, hero: heroOrigin)),
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.isPopular)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '🔥 Populaire',
                        style: context.text.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Text(p.name, style: context.text.titleSmall, maxLines: 2),
                  const SizedBox(height: 4),
                  Text(
                    p.description,
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        Formatters.price(p.price),
                        style: context.text.titleSmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      if (p.calories != null)
                        Text(
                          '  •  ${p.calories} kcal',
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Hero(
                    tag: HeroTags.product(p.id, heroOrigin),
                    child: AppNetworkImage(
                      p.imageUrl,
                      width: imageSize,
                      height: imageSize,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      fallbackIcon: Icons.fastfood_rounded,
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: QuickAddButton(product: p),
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

/// Bouton « + » d'ajout rapide : se transforme en coche verte
/// pendant un instant après l'ajout.
class QuickAddButton extends StatefulWidget {
  const QuickAddButton({super.key, required this.product});

  final Product product;

  @override
  State<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<QuickAddButton> {
  bool _added = false;
  Timer? _resetTimer;

  void _add() {
    CartController.instance.add(CartItem.withDefaults(widget.product));
    HapticFeedback.mediumImpact();
    setState(() => _added = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ajouter ${widget.product.name} au panier',
      child: Pressable(
        onTap: _add,
        scale: 0.8,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOutBack,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _added ? AppColors.success : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.surface, width: 3),
            boxShadow: [
              BoxShadow(
                color: (_added ? AppColors.success : AppColors.primary)
                    .withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: -0.25, end: 0.0).animate(animation),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              _added ? Icons.check_rounded : Icons.add_rounded,
              key: ValueKey(_added),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
