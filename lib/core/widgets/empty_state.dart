import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'primary_button.dart';

/// État vide générique (panier vide, aucun favori, aucun résultat...).
/// Affiche soit une animation Lottie, soit une icône dans un cercle.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.lottieAsset,
    this.actionLabel,
    this.onAction,
  }) : assert(icon != null || lottieAsset != null);

  final String title;
  final String message;
  final IconData? icon;
  final String? lottieAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final illustration = lottieAsset != null
        ? Lottie.asset(lottieAsset!, width: 220, height: 220)
        : Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 52, color: AppColors.primary),
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
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              [
                    illustration,
                    const SizedBox(height: AppSizes.lg),
                    Text(
                      title,
                      style: context.text.headlineSmall,
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
