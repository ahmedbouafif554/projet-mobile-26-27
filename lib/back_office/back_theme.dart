import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_sizes.dart';

/// Ajustements du thème commun pour le panneau web : boutons compacts (le
/// thème mobile les étire sur toute la largeur) et pastilles de filtre
/// teintées plutôt que pleines.
ThemeData backOfficeTheme(ThemeData base) {
  final palette = base.extension<AppPalette>()!;
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
  );
  final label = base.textTheme.labelLarge?.copyWith(
    fontWeight: FontWeight.w600,
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: shape,
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: base.colorScheme.onSurface,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: palette.border, width: 1.5),
        shape: shape,
        textStyle: label,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: AppColors.primary.withValues(alpha: 0.14),
      secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
        color: AppColors.primary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );
}
