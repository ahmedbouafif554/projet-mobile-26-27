import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'shimmer_box.dart';

/// Image réseau avec shimmer pendant le chargement, apparition en fondu
/// et visuel de secours si l'URL ne répond pas.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.restaurant_rounded,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Déjà en cache : on affiche directement.
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          // « passthrough » conserve les contraintes du parent pour que
          // l'image remplisse bien son cadre (BoxFit.cover).
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [...previous, if (current != null) current],
          ),
          child: frame == null
              ? ShimmerBox(
                  key: const ValueKey('placeholder'),
                  width: width,
                  height: height,
                )
              : child,
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          _ImageFallback(icon: fallbackIcon, width: width, height: height),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon, this.width, this.height});

  final IconData icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.35),
            AppColors.primary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: AppColors.primary.withValues(alpha: 0.7),
          size: 32,
        ),
      ),
    );
  }
}
