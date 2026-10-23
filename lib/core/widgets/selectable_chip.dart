import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// Puce de filtre / choix avec transition de couleur animée.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.colors.onSurface;

    return Pressable(
      onTap: onTap,
      scale: 0.93,
      haptic: true,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: selected ? AppColors.primary : context.palette.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              style: context.text.labelLarge!.copyWith(color: foreground),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
