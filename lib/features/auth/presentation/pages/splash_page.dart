import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Écran de démarrage : animation Lottie de bienvenue puis onboarding.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) context.go(AppRoutes.onboarding);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF8A50),
                AppColors.primary,
                AppColors.primaryDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                Lottie.asset(
                  AppAssets.lottieWelcome,
                  width: 230,
                  height: 230,
                  repeat: false,
                ),
                Text(
                      'SuperFaster',
                      style: context.text.displaySmall?.copyWith(
                        color: Colors.white,
                      ),
                    )
                    .animate(delay: 600.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
                const SizedBox(height: 8),
                Text(
                  'Livré plus vite que votre faim',
                  style: context.text.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ).animate(delay: 900.ms).fadeIn(duration: 600.ms),
                const Spacer(flex: 3),
                const _LoadingDots().animate(delay: 1200.ms).fadeIn(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trois points qui pulsent en décalé.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: (i * 180).ms,
            )
            .scaleXY(begin: 0.5, end: 1, duration: 500.ms)
            .fade(begin: 0.4, end: 1);
      }),
    );
  }
}
