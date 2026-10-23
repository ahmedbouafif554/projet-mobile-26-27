import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/responsive_frame.dart';

/// Point d'entrée de SuperFaster (frontend uniquement, données mock).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Barre de statut transparente pour un rendu « edge-to-edge ».
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const SuperFasterApp());
}

class SuperFasterApp extends StatelessWidget {
  const SuperFasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Reconstruit l'application quand l'utilisateur change de thème.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp.router(
        title: 'SuperFaster',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeController.instance.mode,
        // Transition douce entre thème clair et sombre.
        themeAnimationDuration: const Duration(milliseconds: 400),
        routerConfig: AppRouter.router,
        builder: (context, child) => ResponsiveFrame(child: child!),
      ),
    );
  }
}
