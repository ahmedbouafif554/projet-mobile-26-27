import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_routes.dart';
import '../theme/theme_extensions.dart';
import 'pressable.dart';

/// Bouton rond avec icône (retour, favori, partage, panier...).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.backgroundColor,
    this.iconColor,
    this.elevated = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  /// Ajoute une ombre douce (utile sur une image).
  final bool elevated;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onTap,
      scale: 0.88,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? context.colors.surface,
          shape: BoxShape.circle,
          border: elevated ? null : Border.all(color: context.palette.border),
          boxShadow: elevated ? context.palette.softShadow : null,
        ),
        child: Icon(
          icon,
          size: size * 0.48,
          color: iconColor ?? context.colors.onSurface,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Bouton retour standard : revient à la page précédente,
/// ou à [fallbackRoute] s'il n'y a rien à dépiler (ex. : lien direct).
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.elevated = false,
    this.icon,
    this.fallbackRoute = AppRoutes.home,
  });

  final bool elevated;
  final IconData? icon;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon ?? Icons.arrow_back_ios_new_rounded,
      elevated: elevated,
      tooltip: 'Retour',
      onTap: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
    );
  }
}
