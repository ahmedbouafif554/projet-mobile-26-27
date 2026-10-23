import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// Élément de la barre de navigation.
class BottomNavItem {
  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.showDot = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Petite pastille verte (ex. : commande en cours).
  final bool showDot;
}

/// Barre de navigation du bas : l'onglet actif se transforme en « pilule »
/// orange avec son libellé, et son icône rebondit à la sélection.
class AnimatedBottomNav extends StatelessWidget {
  const AnimatedBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.isSmallScreen ? 6 : 12,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.palette.textSecondary;

    Widget icon = Icon(
      selected ? item.activeIcon : item.icon,
      color: color,
      size: 24,
    );
    // Rebond de l'icône à chaque nouvelle sélection.
    if (selected) {
      icon = icon
          .animate()
          .scaleXY(
            begin: 0.6,
            end: 1,
            duration: 500.ms,
            curve: Curves.elasticOut,
          )
          .rotate(begin: -0.08, end: 0, duration: 400.ms);
    }

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        haptic: true,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          // Marges réduites sur les petits écrans (< 360 px).
          padding: EdgeInsets.symmetric(
            horizontal: context.isSmallScreen
                ? (selected ? 12 : 9)
                : (selected ? 16 : 12),
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  icon,
                  if (item.showDot)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: AppDurations.medium,
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
