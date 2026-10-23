import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../orders/presentation/widgets/cart_badge_button.dart';
import '../../../profile/presentation/controllers/notifications_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

/// En-tête de l'accueil : adresse de livraison, notifications et panier.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: ProfileController.instance,
              builder: (context, _) {
                final address = ProfileController.instance.selectedAddress;
                return Pressable(
                  onTap: () => context.push(AppRoutes.addresses),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Livrer à', style: context.text.bodySmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${address.label} • ${address.street}',
                              style: context.text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          const _NotificationBell(),
          const SizedBox(width: 10),
          const CartBadgeButton(),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationsController.instance;

    return ListenableBuilder(
      listenable: notifications,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          CircleIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () => context.push(AppRoutes.notifications),
          ),
          if (notifications.unreadCount > 0)
            Positioned(
              top: 9,
              right: 10,
              child:
                  Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.favorite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 1.5,
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 0.85, end: 1.2, duration: 800.ms),
            ),
        ],
      ),
    );
  }
}
