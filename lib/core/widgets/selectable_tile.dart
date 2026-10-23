import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// Tuile sélectionnable (adresse, moyen de paiement, langue, option...).
/// La bordure, le fond et l'indicateur s'animent à la sélection.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.selected,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.multiple = false,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Widget de tête personnalisé (prioritaire sur [icon]).
  final Widget? leading;

  /// Widget de fin personnalisé (remplace l'indicateur de sélection).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Case à cocher au lieu d'un bouton radio.
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(
                  alpha: context.isDark ? 0.14 : 0.06,
                )
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : context.palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              AnimatedContainer(
                duration: AppDurations.medium,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : context.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? AppColors.primary
                      : context.palette.textSecondary,
                  size: 22,
                ),
              ),
            if (leading != null || icon != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: context.text.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (multiple
                    ? CheckDot(selected: selected)
                    : RadioDot(selected: selected)),
          ],
        ),
      ),
    );
  }
}

/// Bouton radio animé.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : context.palette.textSecondary,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: AppDurations.fast,
        curve: Curves.easeOutBack,
        child: Container(
          width: 11,
          height: 11,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Case à cocher animée.
class CheckDot extends StatelessWidget {
  const CheckDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? AppColors.primary : context.palette.textSecondary,
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: AppDurations.fast,
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}
