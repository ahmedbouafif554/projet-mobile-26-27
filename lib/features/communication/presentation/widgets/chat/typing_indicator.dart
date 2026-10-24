import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';

/// Bulle « … » de l'interlocuteur en train d'écrire : trois points qui
/// sautent en vague (un seul contrôleur pour qu'ils restent synchronisés).
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
          label: "En train d'écrire",
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.palette.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusLg),
                topRight: Radius.circular(AppSizes.radiusLg),
                bottomRight: Radius.circular(AppSizes.radiusLg),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // Chaque point est décalé dans le cycle.
                  final phase = (_controller.value - i * 0.16) % 1.0;
                  final lift = phase < 0.4
                      ? math.sin(phase / 0.4 * math.pi)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(0, -5 * lift),
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      decoration: BoxDecoration(
                        color: context.palette.textSecondary.withValues(
                          alpha: 0.5 + 0.5 * lift,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .scaleXY(
          begin: 0.6,
          end: 1,
          alignment: Alignment.bottomLeft,
          curve: Curves.easeOutBack,
        );
  }
}
