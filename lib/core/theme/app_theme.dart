import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'app_palette.dart';

/// Thème centralisé de l'application (Material 3, clair et sombre).
class AppTheme {
  AppTheme._();

  /// Les polices sont téléchargées par google_fonts au premier lancement.
  /// Les tests (sans réseau) passent ce drapeau à `false`.
  static bool useGoogleFonts = true;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;

    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primary.withValues(
            alpha: isDark ? 0.22 : 0.12,
          ),
          onPrimaryContainer: isDark
              ? AppColors.primaryLight
              : AppColors.primaryDark,
          secondary: isDark ? AppColors.darkTextPrimary : AppColors.secondary,
          onSecondary: isDark ? AppColors.secondary : Colors.white,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainerHighest: palette.surfaceMuted,
          error: AppColors.error,
          outline: palette.border,
          outlineVariant: palette.border,
        );

    final textTheme = _buildTextTheme(textPrimary, palette.textSecondary);
    final radius = BorderRadius.circular(AppSizes.radiusMd);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          side: BorderSide(color: palette.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.primary,
        side: BorderSide(color: palette.border),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        showCheckmark: false,
      ),
      // Barre de navigation des modules (Material 3).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : palette.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.secondary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : palette.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: palette.textSecondary, width: 1.5),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
        indicatorColor: AppColors.primary,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }

  /// Poppins pour les titres, Inter pour le texte courant.
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    TextStyle poppins(double size, FontWeight weight) {
      final style = TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: weight,
        color: primary,
        height: 1.25,
        letterSpacing: 0,
      );
      return useGoogleFonts ? GoogleFonts.poppins(textStyle: style) : style;
    }

    TextStyle inter(double size, FontWeight weight, {Color? color}) {
      final style = TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        color: color ?? primary,
        height: 1.45,
        letterSpacing: 0.1,
      );
      return useGoogleFonts ? GoogleFonts.inter(textStyle: style) : style;
    }

    return TextTheme(
      displayLarge: poppins(40, FontWeight.w700),
      displayMedium: poppins(34, FontWeight.w700),
      displaySmall: poppins(30, FontWeight.w700),
      headlineLarge: poppins(28, FontWeight.w700),
      headlineMedium: poppins(24, FontWeight.w700),
      headlineSmall: poppins(21, FontWeight.w600),
      titleLarge: poppins(18, FontWeight.w600),
      titleMedium: poppins(16, FontWeight.w600),
      titleSmall: poppins(14, FontWeight.w600),
      bodyLarge: inter(16, FontWeight.w400),
      bodyMedium: inter(14, FontWeight.w400),
      bodySmall: inter(12, FontWeight.w400, color: secondary),
      labelLarge: inter(14, FontWeight.w600),
      labelMedium: inter(12, FontWeight.w500),
      labelSmall: inter(11, FontWeight.w500, color: secondary),
    );
  }
}
