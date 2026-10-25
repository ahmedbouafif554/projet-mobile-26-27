import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../data/onboarding_content.dart';

/// Une slide d'onboarding : illustration animée + titre + description.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({super.key, required this.item});

  final OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(child: _Illustration(item: item)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Column(
            children:
                [
                      Text(
                        item.title,
                        style: context.text.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        item.description,
                        style: context.text.bodyLarge?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ]
                    .animate(interval: 120.ms, delay: 200.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.item});

  final OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          300.0,
          math.min(constraints.maxWidth * 0.78, constraints.maxHeight * 0.88),
        );

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Cercles décoratifs
              _circle(
                size,
                item.accent.withValues(alpha: 0.10),
              ).animate().scaleXY(
                begin: 0.6,
                end: 1,
                duration: 700.ms,
                curve: Curves.easeOutBack,
              ),
              _circle(size * 0.82, item.accent.withValues(alpha: 0.16))
                  .animate(delay: 100.ms)
                  .scaleXY(
                    begin: 0.6,
                    end: 1,
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  ),
              // Photo centrale
              ClipOval(
                    child: AppNetworkImage(
                      item.imageUrl,
                      width: size * 0.66,
                      height: size * 0.66,
                    ),
                  )
                  .animate(delay: 150.ms)
                  .scaleXY(
                    begin: 0.4,
                    end: 1,
                    duration: 900.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 300.ms),
              // Étiquettes flottantes
              if (item.badges.isNotEmpty)
                Positioned(
                  top: size * 0.06,
                  left: -size * 0.02,
                  child: _FloatingBadge(badge: item.badges[0], delay: 400),
                ),
              if (item.badges.length > 1)
                Positioned(
                  bottom: size * 0.08,
                  right: -size * 0.04,
                  child: _FloatingBadge(
                    badge: item.badges[1],
                    delay: 600,
                    reverse: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.badge,
    required this.delay,
    this.reverse = false,
  });

  final (String, String) badge;
  final int delay;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: context.palette.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge.$1, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(badge.$2, style: context.text.labelLarge),
            ],
          ),
        )
        .animate(delay: delay.ms)
        .fadeIn(duration: 400.ms)
        .scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack)
        // Flottement continu (animation imbriquée qui boucle)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: reverse ? 6 : -6,
          end: reverse ? -6 : 6,
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}
