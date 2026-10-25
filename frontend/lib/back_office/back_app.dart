import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app/bootstrap.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import 'back_theme.dart';
import 'router/back_router.dart';

/// Panneau web (back office « Espace Pro ») : admin et restaurants.
class BackOfficeApp extends ConsumerWidget {
  const BackOfficeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SuperFaster • Espace Pro',
      debugShowCheckedModeBanner: false,
      theme: backOfficeTheme(AppTheme.light),
      darkTheme: backOfficeTheme(AppTheme.dark),
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 400),
      locale: AppLocalization.locale,
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: AppLocalization.delegates,
      routerConfig: ref.watch(backRouterProvider),
    );
  }
}
