import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../router/front_routes.dart';
import '../../providers/onboarding_provider.dart';

/// Écran de démarrage : animation de bienvenue, puis accueil (déjà
/// connecté), connexion (onboarding déjà vu) ou onboarding.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Durée d'affichage avant de passer à la suite.
  static const duration = Duration(milliseconds: 2800);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashPage.duration, _next);
  }

  void _next() {
    if (!mounted) return;
    final role = ref.read(authServiceProvider).role;
    final target = role != null
        ? FrontRoutes.homeFor(role)
        : ref.read(onboardingSeenProvider)
        ? FrontRoutes.login
        : FrontRoutes.onboarding;
    context.go(target);
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
                  width: 220,
                  height: 220,
                  repeat: false,
                ),
                Text(
                      'SuperFaster',
                      style: context.text.displaySmall?.copyWith(
                        color: Colors.white,
                      ),
                    )
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
                const SizedBox(height: 8),
                Text(
                  'Livré plus vite que votre faim',
                  style: context.text.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ).animate(delay: 800.ms).fadeIn(duration: 600.ms),
                const Spacer(flex: 3),
                const _LoadingDots().animate(delay: 1100.ms).fadeIn(),
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
      children: [
        for (var i = 0; i < 3; i++)
          Container(
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
              .fade(begin: 0.4, end: 1),
      ],
    );
  }
}
