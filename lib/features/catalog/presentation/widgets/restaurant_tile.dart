import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/info_chip.dart';
import '../../../../core/widgets/pressable.dart';
import '../../models/restaurant.dart';
import 'favorite_button.dart';
import 'restaurant_card.dart';

/// Tuile horizontale de restaurant (listes, recherche, favoris).
class RestaurantTile extends StatelessWidget {
  const RestaurantTile({
    super.key,
    required this.restaurant,
    required this.heroOrigin,
  });

  final Restaurant restaurant;
  final String heroOrigin;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final imageSize = context.isSmallScreen ? 84.0 : 96.0;

    return Pressable(
      onTap: () =>
          context.push(AppRoutes.restaurantDetail(r.id, hero: heroOrigin)),
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: context.palette.softShadow,
        ),
        child: Row(
          children: [
            Hero(
              tag: HeroTags.restaurant(r.id, heroOrigin),
              child: AppNetworkImage(
                r.imageUrl,
                width: imageSize,
                height: imageSize,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: context.text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.cuisine,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      InfoChip(
                        icon: Icons.star_rounded,
                        label: r.rating.toStringAsFixed(1).replaceAll('.', ','),
                        iconColor: context.palette.warning,
                      ),
                      InfoChip(
                        icon: Icons.schedule_rounded,
                        label: r.deliveryTimeLabel,
                      ),
                      InfoChip(
                        icon: Icons.place_outlined,
                        label: Formatters.distance(r.distanceKm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DeliveryFeeChip(fee: r.deliveryFee),
                      if (r.promo != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: PromoBadge(label: r.promo!, small: true),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.topCenter,
              child: FavoriteButton(
                restaurantId: r.id,
                size: 34,
                elevated: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
