import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../controllers/cart_controller.dart';

/// Icône du panier avec badge animé : le badge « rebondit »
/// à chaque changement du nombre d'articles.
class CartBadgeButton extends StatelessWidget {
  const CartBadgeButton({super.key, this.elevated = false});

  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final cart = CartController.instance;

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final count = cart.itemCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CircleIconButton(
              icon: Icons.shopping_bag_outlined,
              elevated: elevated,
              tooltip: 'Panier',
              onTap: () => context.push(AppRoutes.cart),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child:
                    Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: context.colors.surface,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: context.text.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        // La clé change avec le nombre : l'animation est rejouée.
                        .animate(key: ValueKey(count))
                        .scaleXY(
                          begin: 0.3,
                          end: 1,
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),
              ),
          ],
        );
      },
    );
  }
}
