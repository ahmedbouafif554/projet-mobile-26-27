import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';

/// Applique un seul effet shimmer synchronisé à tout un squelette de page.
/// À combiner avec des [SkeletonBox].
class ShimmerScope extends StatelessWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.palette.shimmerBase,
      highlightColor: context.palette.shimmerHighlight,
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }
}

/// Bloc gris représentant un contenu en cours de chargement.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppSizes.radiusSm,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Raccourci : un seul bloc avec son propre shimmer (ex. : image en chargement).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = 0});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: SkeletonBox(width: width, height: height, radius: radius),
    );
  }
}
