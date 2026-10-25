import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app/bootstrap.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../core/widgets/responsive_frame.dart';
import 'router/front_router.dart';

/// Application mobile (front office) : clients et livreurs.
class FrontOfficeApp extends ConsumerWidget {
  const FrontOfficeApp({super.key});

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
