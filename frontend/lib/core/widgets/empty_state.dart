import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'primary_button.dart';

/// État vide générique (panier vide, aucun favori, tableau sans résultat…).
/// Affiche une icône dans un cercle si [icon] est fourni, sinon une animation
/// Lottie ([lottieAsset], par défaut l'animation « vide »).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.lottieAsset,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? lottieAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Version réduite (dans un tableau, une carte…).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 140.0 : 220.0;
    final illustration = icon == null
        ? Lottie.asset(
            lottieAsset ?? AppAssets.lottieEmpty,
            width: size,
            height: size,
          )
        : Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: size * 0.24, color: AppColors.primary),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: 1600.ms,
                curve: Curves.easeInOut,
              );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? AppSizes.md : AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              [
                    illustration,
                    SizedBox(height: compact ? AppSizes.sm : AppSizes.lg),
                    Text(
                      title,
                      style: compact
                          ? context.text.titleMedium
                          : context.text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      message,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: AppSizes.lg),
                      PrimaryButton(label: actionLabel!, onPressed: onAction),
                    ],
                  ]
                  .animate(interval: 80.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}
