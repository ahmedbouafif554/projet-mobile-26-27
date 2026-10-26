import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../back_office/back_app.dart';
import '../core/app/bootstrap.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/permissions.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../core/widgets/responsive_frame.dart';
import 'router/front_router.dart';

/// Une seule fenêtre : connexion commune, puis l'espace du rôle.
/// Client et livreur restent dans l'application mobile. Admin et
/// restaurant passent au tableau de bord, sans ouvrir une autre fenêtre.
class FrontOfficeApp extends ConsumerWidget {
  const FrontOfficeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authServiceProvider.select((auth) => auth.role));
    if (role != null && Permissions.canAccess(role, AppSpace.backOffice)) {
      return const BackOfficeApp(key: ValueKey('back-office'));
    }
    return const _MobileApp(key: ValueKey('front-office'));
  }
}

class _MobileApp extends ConsumerWidget {
  const _MobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SuperFaster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 400),
      locale: AppLocalization.locale,
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: AppLocalization.delegates,
      routerConfig: ref.watch(frontRouterProvider),
      // Sur tablette ou navigateur, l'app garde un format téléphone centré.
      builder: (context, child) => ResponsiveFrame(child: child!),
    );
  }
}
