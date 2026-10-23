import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fait « trembler » son enfant horizontalement à chaque fois que
/// [trigger] change de valeur (et n'est pas nul).
/// Idéal pour signaler une erreur de saisie.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.child, this.trigger});

  final Widget child;
  final Object? trigger;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        // Oscillation amortie : forte au début, nulle à la fin.
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
