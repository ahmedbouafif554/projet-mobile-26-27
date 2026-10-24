import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/config/modules_config.dart';
import 'package:superfaster/core/routes/app_router.dart';
import 'package:superfaster/core/routes/app_routes.dart';
import 'package:superfaster/features/communication/communication_routes.dart';

/// Vérifie la cohérence de modules_config.dart et des fichiers de routes.
/// À lancer après chaque modification d'un module (`flutter test`).
void main() {
  const modules = ModulesConfig.modules;

  /// Écran prévu correspondant à un chemin `/<module>/<écran>` (ou à la
  /// route du module : son écran principal), ou null.
  PlannedScreen? screenOf(String location) {
    final path = Uri.parse(location).path;
    for (final module in modules) {
      if (path == module.route) return module.screen(module.homeScreen);
      if (path.startsWith('${module.route}/')) {
        return module.screen(path.substring(module.route.length + 1));
      }
    }
    return null;
  }

  test('numéros, routes, dossiers et labels des modules sont uniques', () {
    for (final key in <Object Function(AppModule)>[
      (m) => m.number,
      (m) => m.route,
      (m) => m.folder,
      (m) => m.label,
    ]) {
      expect(modules.map(key).toSet(), hasLength(modules.length));
    }
    for (final m in modules) {
      expect(m.route, startsWith('/'), reason: 'Route du module ${m.number}');
      expect(
        m.label.length,
        lessThanOrEqualTo(10),
        reason: 'Label trop long pour la barre : ${m.label}',
      );
    }
  });

  test('les identifiants d\'écrans sont uniques dans chaque module', () {
    for (final m in modules) {
      final ids = m.screens.map((s) => s.id).toList();
      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason: 'Doublon dans le module ${m.number}',
      );
      for (final id in ids) {
        expect(
          RegExp(r'^[a-z0-9-]+$').hasMatch(id),
          isTrue,
          reason: 'Identifiant invalide : $id',
        );
      }
    }
  });

  test('chaque fichier de routes ne déclare que des écrans prévus', () {
    expect(AppRouter.moduleRoutes, hasLength(modules.length));
    for (final routes in AppRouter.moduleRoutes) {
      final module = ModulesConfig.byNumber(routes.moduleNumber);
      for (final id in {...routes.screens.keys, ...routes.transitions.keys}) {
        expect(
          module.screen(id),
          isNotNull,
          reason:
              'Module ${module.number} : l\'écran « $id » n\'existe pas dans modules_config.dart',
        );
      }
    }
  });

  test(
    'les chemins de AppRoutes et CommunicationRoutes sont des écrans prévus',
    () {
      const paths = [
        ModulesConfig.initialRoute,
        ModulesConfig.loginRoute,
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.otp,
        AppRoutes.forgotPassword,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.addresses,
        AppRoutes.language,
        AppRoutes.admin,
        AppRoutes.home,
        AppRoutes.search,
        AppRoutes.restaurants,
        AppRoutes.restaurant,
        AppRoutes.product,
        AppRoutes.favorites,
        AppRoutes.cart,
        AppRoutes.checkout,
        AppRoutes.paymentMethods,
        AppRoutes.orderConfirmation,
        AppRoutes.orders,
        AppRoutes.tracking,
        AppRoutes.parcel,
        CommunicationRoutes.notifications,
        CommunicationRoutes.notificationSettings,
        CommunicationRoutes.chats,
        CommunicationRoutes.reviews,
        CommunicationRoutes.myReviews,
        CommunicationRoutes.moderation,
        CommunicationRoutes.newReview,
      ];
      for (final path in paths) {
        expect(screenOf(path), isNotNull, reason: path);
      }
      expect(modules.any((m) => m.route == ModulesConfig.homeRoute), isTrue);
    },
  );

  test('chaque onglet s\'ouvre sur un vrai écran, dans l\'onglet', () {
    for (final m in modules) {
      final home = m.screen(m.homeScreen);
      expect(home, isNotNull, reason: 'Module ${m.number} : ${m.homeScreen}');
      expect(home!.fullScreen, isFalse, reason: m.homeScreen);
      expect(m.routeOf(m.homeScreen), m.route);
      expect(
        AppRouter.routesOf(m).isReady(m.homeScreen),
        isTrue,
        reason: 'Module ${m.number} : écran principal non développé',
      );
    }
  });
}
