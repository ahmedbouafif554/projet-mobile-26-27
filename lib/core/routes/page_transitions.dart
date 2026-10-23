import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Types de transitions personnalisées disponibles.
enum PageTransitionType { fade, slide, slideUp, scale }

/// Construit une page go_router avec la transition demandée.
CustomTransitionPage<T> buildTransitionPage<T>({
  required GoRouterState state,
  required Widget child,
  PageTransitionType type = PageTransitionType.slide,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurveTween(curve: Curves.easeOutCubic);

      return switch (type) {
        // Fondu simple
        PageTransitionType.fade => FadeTransition(
          opacity: animation.drive(curve),
          child: child,
        ),

        // Glissement depuis la droite + léger fondu
        PageTransitionType.slide => SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(1, 0), end: Offset.zero).chain(curve),
          ),
          child: FadeTransition(
            opacity: animation.drive(Tween(begin: 0.5, end: 1.0).chain(curve)),
            child: child,
          ),
        ),

        // Montée depuis le bas (pages « modales » : panier, paiement...)
        PageTransitionType.slideUp => SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, 0.15), end: Offset.zero).chain(curve),
          ),
          child: FadeTransition(opacity: animation.drive(curve), child: child),
        ),

        // Zoom avant + fondu (confirmation, détails)
        PageTransitionType.scale => ScaleTransition(
          scale: animation.drive(Tween(begin: 0.9, end: 1.0).chain(curve)),
          child: FadeTransition(opacity: animation.drive(curve), child: child),
        ),
      };
    },
  );
}
