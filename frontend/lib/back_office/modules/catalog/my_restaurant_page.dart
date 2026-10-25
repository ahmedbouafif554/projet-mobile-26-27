import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../shared/models/models.dart';
import '../../shell/bo_page.dart';
import 'catalog_controllers.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_form.dart';

/// « Mon restaurant » (restaurateur) : ouverture aux commandes, fiche du
/// restaurant et modification de ses informations.
class MyRestaurantPage extends ConsumerWidget {
  const MyRestaurantPage({super.key});

  Future<void> _setOpen(
    BuildContext context,
    WidgetRef ref,
    Restaurant restaurant,
    bool open,
  ) async {
    try {
      await ref
          .read(restaurantsControllerProvider.notifier)
          .save(restaurant.copyWith(isOpen: open), isNew: false);
      if (context.mounted) {
        AppSnackbar.success(
          context,
          open
              ? 'Restaurant ouvert : vous recevez des commandes'
              : 'Restaurant fermé : plus de nouvelles commandes',
        );
      }
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantId = ref.watch(
      authServiceProvider.select((a) => a.user?.restaurantId),
    );
    final restaurants = ref.watch(restaurantsControllerProvider);
    final restaurant = restaurants.value
        ?.where((r) => r.id == restaurantId)
        .firstOrNull;

    if (restaurant == null) {
      return BoPage(
        title: 'Mon restaurant',
        children: [
          if (restaurants.isLoading)
            const ShimmerScope(
              child: SkeletonBox(height: 260, radius: AppSizes.radiusLg),
            )
          else
            const AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.storefront_rounded,
                title: 'Aucun restaurant associé',
                message: 'Contactez le support SuperFaster.',
              ),
            ),
        ],
      );
    }

    return BoPage(
      title: 'Mon restaurant',
      subtitle: 'Ce que vos clients voient dans l’application.',
      actions: [
        FilledButton.icon(
          onPressed: () => openRestaurantForm(context, restaurant: restaurant),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Modifier les informations'),
        ),
      ],
      children: [
        _OpenSwitch(
          isOpen: restaurant.isOpen,
          onChanged: (open) => _setOpen(context, ref, restaurant, open),
        ),
        boGap,
        RestaurantOverview(restaurant: restaurant),
      ],
    );
  }
}

/// Grand interrupteur « Ouvert aux commandes ».
class _OpenSwitch extends StatelessWidget {
  const _OpenSwitch({required this.isOpen, required this.onChanged});

  final bool isOpen;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : context.palette.textSecondary;
    return AnimatedContainer(
      duration: AppDurations.medium,
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: AppDurations.medium,
            child: Icon(
              isOpen ? Icons.storefront_rounded : Icons.nightlight_round,
              key: ValueKey(isOpen),
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Ouvert aux commandes' : 'Fermé',
                  style: context.text.titleMedium,
                ),
                Text(
                  isOpen
                      ? 'Les clients peuvent commander maintenant.'
                      : 'Votre restaurant est visible mais ne reçoit plus de commandes.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: isOpen,
              activeTrackColor: AppColors.success,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
