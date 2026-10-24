import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Couleurs complémentaires non couvertes par [ColorScheme]
/// (statuts, textes secondaires, shimmer, ombres...).
/// Accessible via `context.palette` (voir theme_extensions.dart).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.warning,
    required this.info,
    required this.textSecondary,
    required this.border,
    required this.surfaceMuted,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.shadow,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color textSecondary;
  final Color border;
  final Color surfaceMuted;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color shadow;

  static const AppPalette light = AppPalette(
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    textSecondary: AppColors.textSecondary,
    border: AppColors.border,
    surfaceMuted: AppColors.surfaceMuted,
    shimmerBase: Color(0xFFECECF1),
    shimmerHighlight: Color(0xFFF9F9FB),
    shadow: Color(0x14101018),
  );

  static const AppPalette dark = AppPalette(
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    textSecondary: AppColors.darkTextSecondary,
    border: AppColors.darkBorder,
    surfaceMuted: AppColors.darkSurfaceMuted,
    shimmerBase: Color(0xFF24242A),
    shimmerHighlight: Color(0xFF34343C),
    shadow: Color(0x66000000),
  );

  /// Ombre douce standard des cartes.
  List<BoxShadow> get softShadow => [
    BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
  ];

  @override
  AppPalette copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? textSecondary,
    Color? border,
    Color? surfaceMuted,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? shadow,
  }) {
    return AppPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
