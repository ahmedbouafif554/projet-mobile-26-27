import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';

/// Nombre qui défile jusqu'à sa valeur (et d'une valeur à l'autre quand
/// elle change). [format] choisit l'affichage : prix, entier, pourcentage…
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = AppDurations.counter,
  });

  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Part de 0 au premier affichage, puis de l'ancienne valeur.
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text(
        format(value is int ? current.round() : current),
        style: style,
        maxLines: 1,
      ),
    );
  }
}
