import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// Bouton principal de l'application : dégradé orange, ombre colorée,
/// effet d'appui et état de chargement animé.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailing,
    this.isLoading = false,
    this.color,
    this.height = AppSizes.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Widget affiché à droite (ex. : prix total).
  final Widget? trailing;
  final bool isLoading;

  /// Couleur unie à la place du dégradé (ex. : vert pour un succès).
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final baseColor = color ?? AppColors.primary;
    final labelStyle = context.text.titleMedium?.copyWith(color: Colors.white);

    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: true,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled && color == null ? AppColors.primaryGradient : null,
          color: enabled
              ? (color == null ? null : baseColor)
              : context.palette.border,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: AnimatedSwitcher(
          duration: AppDurations.fast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: ValueKey(label),
                  mainAxisSize: trailing == null
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      fit: trailing == null ? FlexFit.loose : FlexFit.tight,
                      child: Text(
                        label,
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null)
                      DefaultTextStyle.merge(
                        style: labelStyle,
                        child: trailing!,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
