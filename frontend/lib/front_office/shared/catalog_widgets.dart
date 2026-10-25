import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/pressable.dart';
import '../../shared/models/models.dart';
import '../modules/catalog/providers/catalog_providers.dart';

// =============================================================================
// Widgets du catalogue réutilisés par l'accueil, la recherche, les favoris
// et les listes de restaurants.
// =============================================================================

/// Cœur des favoris (rebond à l'ajout).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.restaurantId,
    this.size = 36,
    this.onImage = true,
  });

  final String restaurantId;
  final double size;

  /// Fond blanc translucide (posé sur une photo).
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite =
        ref.watch(favoritesProvider).value?.contains(restaurantId) ?? false;
    return Material(
      color: onImage
          ? Colors.white.withValues(alpha: 0.92)
          : context.palette.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          try {
            final added = await ref
                .read(favoritesProvider.notifier)
                .toggle(restaurantId);
            if (context.mounted) {
              AppSnackbar.show(
                context,
                added ? 'Ajouté aux favoris' : 'Retiré des favoris',
                icon: added
                    ? Icons.favorite_rounded
                    : Icons.heart_broken_rounded,
                iconColor: AppColors.favorite,
              );
            }
          } catch (error) {
            if (context.mounted) AppSnackbar.error(context, error);
          }
        },
        child: SizedBox.square(
          dimension: size,
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
              ),
              child: child,
            ),
            child: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(isFavorite),
              size: size * 0.5,
              color: isFavorite
                  ? AppColors.favorite
                  : (onImage ? AppColors.textPrimary : context.colors.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Note ★ 4,7 (1 240).
class RatingLabel extends StatelessWidget {
  const RatingLabel({
    super.key,
    required this.rating,
    this.count,
    this.dense = false,
  });

  final double rating;
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = dense ? context.text.labelMedium : context.text.labelLarge;
    if (count == 0) {
      return Text(
        'Nouveau',
        style: style?.copyWith(color: AppColors.success),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: dense ? 15 : 17, color: AppColors.warning),
        const SizedBox(width: 3),
        Text(Formatters.rating(rating), style: style),
        if (count != null)
          Text(
            ' (${Formatters.compact(count!)})',
            style: style?.copyWith(color: context.palette.textSecondary),
          ),
      ],
    );
  }
}

/// Petite info avec icône (« 🕒 20-30 min »).
class InfoTag extends StatelessWidget {
  const InfoTag({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Bandeau d'offre (« -20 % »).
class PromoBadge extends StatelessWidget {
  const PromoBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_offer_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grande carte d'un restaurant : photo, offre, favori, infos de livraison.
/// Grisée quand le restaurant est fermé.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.width,
    this.imageHeight = 150,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final double? width;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: context.palette.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      r.isOpen ? Colors.transparent : Colors.grey,
                      r.isOpen ? BlendMode.dst : BlendMode.saturation,
                    ),
                    child: AppNetworkImage(r.imageUrl, height: imageHeight),
                  ),
                  if (!r.isOpen)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: const Text(
                        'Fermé pour le moment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (r.promo != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: PromoBadge(label: r.promo!),
                    ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: FavoriteButton(restaurantId: r.id),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.deliveryTimeLabel,
                        style: context.text.labelMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                      RatingLabel(rating: r.rating, count: r.reviewCount),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.cuisine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      InfoTag(
                        icon: Icons.delivery_dining_rounded,
                        label: r.deliveryFee == 0
                            ? 'Livraison offerte'
                            : Formatters.price(r.deliveryFee),
                      ),
                      InfoTag(
                        icon: Icons.place_outlined,
                        label: Formatters.distance(r.distanceKm),
                      ),
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

/// Ligne compacte d'un restaurant (recherche, favoris).
class RestaurantTile extends StatelessWidget {
  const RestaurantTile({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.trailing,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: context.palette.softShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: AppNetworkImage(r.imageUrl, width: 76, height: 76),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  Text(
                    r.cuisine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingLabel(
                        rating: r.rating,
                        count: r.reviewCount == 0 ? 0 : null,
                        dense: true,
                      ),
                      InfoTag(
                        icon: Icons.schedule_rounded,
                        label: r.deliveryTimeLabel,
                      ),
                      if (!r.isOpen)
                        Text(
                          'Fermé',
                          style: context.text.labelMedium?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            trailing ?? FavoriteButton(restaurantId: r.id, onImage: false),
          ],
        ),
      ),
    );
  }
}

/// Pastille d'une catégorie (emoji dans un cercle coloré + libellé).
class CategoryBubble extends StatelessWidget {
  const CategoryBubble({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
  });

  final Category category;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Color(category.colorValue).withValues(alpha: 0.18)
                    : Color(category.colorValue),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Text(category.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(
                color: selected ? AppColors.primary : null,
                fontWeight: selected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plat dans un menu : texte à gauche, photo et bouton « + » à droite.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.quantityInCart = 0,
  });

  final Product product;
  final VoidCallback onTap;
  final int quantityInCart;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Opacity(
      opacity: p.isAvailable ? 1 : 0.5,
      child: InkWell(
        onTap: p.isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (p.isPopular) ...[
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            p.name,
                            style: context.text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
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
                        if (p.calories != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${p.calories} kcal',
                            style: context.text.labelSmall?.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                        if (!p.isAvailable) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Épuisé',
                            style: context.text.labelMedium?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      child: AppNetworkImage(p.imageUrl, width: 96, height: 96),
                    ),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: AnimatedSwitcher(
                        duration: AppDurations.fast,
                        transitionBuilder: (child, a) =>
                            ScaleTransition(scale: a, child: child),
                        child: Container(
                          key: ValueKey(quantityInCart),
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: quantityInCart > 0
                                ? AppColors.primary
                                : context.colors.surface,
                            shape: BoxShape.circle,
                            boxShadow: context.palette.softShadow,
                          ),
                          child: quantityInCart > 0
                              ? Text(
                                  '$quantityInCart',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_rounded,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
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

/// Sélecteur de quantité − 2 +.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 40.0;
    Widget button(IconData icon, VoidCallback? onTap, String tooltip) =>
        Material(
          color: onTap == null
              ? context.palette.surfaceMuted
              : AppColors.primary.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Tooltip(
              message: tooltip,
              child: SizedBox.square(
                dimension: size,
                child: Icon(
                  icon,
                  size: compact ? 16 : 20,
                  color: onTap == null
                      ? context.palette.textSecondary
                      : AppColors.primary,
                ),
              ),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          // Avec un minimum à 0 (panier), passer sous 1 retire la ligne.
          min == 0 && value <= 1
              ? Icons.delete_outline_rounded
              : Icons.remove_rounded,
          value > min ? () => onChanged(value - 1) : null,
          'Retirer',
        ),
        SizedBox(
          width: compact ? 30 : 40,
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Text(
              '$value',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: compact ? context.text.titleSmall : context.text.titleMedium,
            ),
          ),
        ),
        button(
          Icons.add_rounded,
          value < max ? () => onChanged(value + 1) : null,
          'Ajouter',
        ),
      ],
    );
  }
}

/// Étoiles de saisie animées (rebond à la sélection).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 44,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedScale(
                scale: i <= value ? 1.08 : 0.92,
                duration: const Duration(milliseconds: 250),
                curve: Curves.elasticOut,
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= value
                      ? AppColors.warning
                      : context.palette.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
              .animate(key: ValueKey('$i-${i <= value}'))
              .shimmer(
                duration: i <= value ? 500.ms : 1.ms,
                color: Colors.white54,
              ),
      ],
    );
  }
}

/// Étoiles en lecture seule.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final num rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: AppColors.warning,
          ),
      ],
    );
  }
}
