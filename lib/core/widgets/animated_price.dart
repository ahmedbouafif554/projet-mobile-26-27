import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Prix qui « défile » vers sa nouvelle valeur quand il change
/// (ex. : total du panier qui se met à jour).
class AnimatedPrice extends StatelessWidget {
  const AnimatedPrice(this.value, {super.key, this.style, this.prefix = ''});

  final double value;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) =>
          Text('$prefix${Formatters.price(animatedValue)}', style: style),
    );
  }
}
