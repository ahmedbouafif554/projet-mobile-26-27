import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/responsive_frame.dart';
import 'features/communication/presentation/controllers/conversations_controller.dart';
import 'features/communication/presentation/controllers/notification_center_controller.dart';
import 'features/communication/presentation/widgets/notifications/in_app_banner_host.dart';

/// Point d'entrée de SuperFaster (frontend, données mock par défaut).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Barre de statut transparente pour un rendu « edge-to-edge ».
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  // Précharge les compteurs (cloche, messages non lus).
  NotificationCenterController.instance.load();
  ConversationsController.instance.load();
  runApp(const SuperFasterApp());
}

class SuperFasterApp extends StatelessWidget {
  const SuperFasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router;

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
        routerConfig: router,
        builder: (context, child) => ResponsiveFrame(
          // Bannières in-app (notifications « push ») au-dessus de tous les écrans.
          child: InAppBannerHost(
            onOpen: router.push,
            currentLocation: () =>
                router.routerDelegate.currentConfiguration.uri.toString(),
            child: child!,
          ),
        ),
      ),
    );
  }
}
