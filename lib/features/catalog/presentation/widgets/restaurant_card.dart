import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/info_chip.dart';
import '../../../../core/widgets/pressable.dart';
import '../../models/restaurant.dart';
import 'favorite_button.dart';

/// Grande carte verticale (section « Populaires » de l'accueil).
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.heroOrigin,
    this.width = 260,
  });

  final Restaurant restaurant;

  /// Préfixe du tag Hero (doit être unique par liste affichée).
  final String heroOrigin;
  final double width;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    const radius = Radius.circular(AppSizes.radiusLg);

    return Pressable(
      onTap: () =>
          context.push(AppRoutes.restaurantDetail(r.id, hero: heroOrigin)),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.all(radius),
          boxShadow: context.palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: HeroTags.restaurant(r.id, heroOrigin),
                  child: AppNetworkImage(
                    r.imageUrl,
                    width: width,
                    height: 140,
                    borderRadius: const BorderRadius.vertical(top: radius),
                  ),
                ),
                if (r.promo != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: PromoBadge(label: r.promo!),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FavoriteButton(restaurantId: r.id, size: 36),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: context.text.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RatingPill(rating: r.rating),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.cuisine,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InfoChip(
                        icon: Icons.schedule_rounded,
                        label: r.deliveryTimeLabel,
                      ),
                      const SizedBox(width: 12),
                      DeliveryFeeChip(fee: r.deliveryFee),
                    ],
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

/// Étiquette de promotion orange (ex. « -20% »).
class PromoBadge extends StatelessWidget {
  const PromoBadge({super.key, required this.label, this.small = false});

  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_offer_rounded,
            size: small ? 11 : 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (small ? context.text.labelSmall : context.text.labelMedium)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frais de livraison, en vert quand ils sont offerts.
class DeliveryFeeChip extends StatelessWidget {
  const DeliveryFeeChip({super.key, required this.fee});

  final double fee;

  @override
  Widget build(BuildContext context) {
    final free = fee == 0;
    return InfoChip(
      icon: Icons.delivery_dining_rounded,
      label: free ? 'Offerte' : Formatters.price(fee),
      iconColor: free ? AppColors.success : null,
      textColor: free ? AppColors.success : null,
    );
  }
}
