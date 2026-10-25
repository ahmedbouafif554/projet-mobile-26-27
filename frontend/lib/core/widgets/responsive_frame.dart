import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Garde une mise en page « téléphone » lisible sur les grands écrans
/// (tablettes, web) : le contenu est centré et limité en largeur.
/// Sur téléphone, ce widget ne change rien.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    if (width <= maxWidth) return child;

    final frameWidth = math.min(width, maxWidth);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: frameWidth,
          // On met à jour la taille exposée pour que les widgets
          // qui lisent MediaQuery se calent sur la largeur réelle.
          child: MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(frameWidth, mediaQuery.size.height),
            ),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
