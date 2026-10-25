import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/front_office/modules/auth/presentation/pages/profile_page.dart';
import 'package:superfaster/front_office/router/front_routes.dart';
import 'package:superfaster/shared/mock/mock_delivery.dart';
import 'package:superfaster/shared/models/models.dart';

import '../test_helpers.dart';
import 'front_test_utils.dart';

/// Parcours du module 1 dans le front office.
void main() {
  setUpAll(setUpAppTestEnvironment);

  testWidgets(
    'client : splash → onboarding → connexion → onglets → déconnexion',
    (tester) async {
      final restore = ignoreOfflineImageErrors();
      final app = await pumpFront(tester);
      expect(find.text('SuperFaster'), findsOneWidget);

      // Le splash enchaîne seul sur l'onboarding.
      await settle(tester, 3200);
      expect(app.path, FrontRoutes.onboarding);
      await tester.tap(find.text('Passer'));
      await settle(tester);
      expect(app.path, FrontRoutes.login);

      // Champs pré-remplis avec le compte client de démo.
      await tester.tap(find.text('Se connecter'));
      await settle(tester);
      expect(app.path, FrontRoutes.explore);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      for (final label in [
        'Explorer',
        'Recherche',
        'Panier',
        'Commandes',
        'Profil',
      ]) {
        expect(navLabel(label), findsOneWidget);
      }

      // Profil puis déconnexion.
      await tester.tap(navLabel('Profil'));
      await settle(tester);
      expect(find.text('Alex Martin'), findsOneWidget);
      await scrollTo(tester, find.text('Déconnexion'), ProfilePage);
      await tester.tap(find.text('Déconnexion'));
      await settle(tester, 600);
      await tester.tap(find.widgetWithText(FilledButton, 'Déconnexion'));
      await settle(tester);
      expect(app.path, FrontRoutes.login);
      expect(app.container.read(authServiceProvider).isLoggedIn, isFalse);

      expect(tester.takeException(), isNull);
      await unmountFront(tester);
      restore();
    },
  );

  testWidgets('livreur : rôle choisi à la connexion, onglets et badges', (
    tester,
  ) async {
    final restore = ignoreOfflineImageErrors();
    final app = await pumpFront(tester, location: FrontRoutes.login);

    // Le rôle « Livreur » avec le compte client : refusé.
    final email = find.byType(TextField).first;
    await tester.tap(find.text('Livreur'));
    await settle(tester, 400);
    await tester.enterText(email, 'alex.martin@exemple.fr');
    await tester.tap(find.text('Se connecter'));
    await settle(tester, 600);
    expect(find.textContaining('compte client'), findsOneWidget);
    expect(app.path, FrontRoutes.login);
    await settle(tester, 3000);

    // Le compte livreur de démo.
    await tester.enterText(email, 'karim.benali@superfaster.fr');
    await tester.tap(find.text('Se connecter'));
    await settle(tester);
    expect(app.path, FrontRoutes.courierDashboard);
    for (final label in [
      'Dashboard',
      'Livraisons',
      'Gains',
      'Messages',
      'Profil',
    ]) {
      expect(navLabel(label), findsOneWidget);
    }
    // Badge : courses en attente d'un livreur.
    final offers = MockDelivery.deliveries
        .where((d) => d.status == DeliveryStatus.waiting)
        .length;
    expect(navLabel('$offers'), findsOneWidget);

    // Un livreur n'ouvre pas les écrans du client.
    app.go(FrontRoutes.explore);
    await settle(tester);
    expect(app.path, FrontRoutes.courierDashboard);

    expect(tester.takeException(), isNull);
    await unmountFront(tester);
    restore();
  });

  testWidgets('inscription → vérification OTP → accueil', (tester) async {
    final restore = ignoreOfflineImageErrors();
    final app = await pumpFront(tester, location: FrontRoutes.login);

    await tester.tap(find.text("S'inscrire"));
    await settle(tester);
    expect(app.path, FrontRoutes.register);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nina');
    await tester.enterText(fields.at(1), 'Simon');
    await tester.enterText(fields.at(2), 'nina.simon@exemple.fr');
    await tester.enterText(fields.at(3), '0611223344');
    await tester.enterText(fields.at(4), 'secret12');
    await tester.enterText(fields.at(5), 'secret12');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await settle(tester);
    expect(app.path, FrontRoutes.otp);

    // Mauvais code, puis le bon (1234).
    await tester.enterText(find.byType(TextField), '0000');
    await settle(tester, 1000);
    expect(find.text('Code incorrect, veuillez réessayer.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), AuthService.demoOtpCode);
    await settle(tester, 1000);
    expect(find.text('Numéro vérifié !'), findsOneWidget);
    await settle(tester, 2000);

    expect(app.path, FrontRoutes.explore);
    final user = app.container.read(authServiceProvider).user;
    expect(user?.fullName, 'Nina Simon');
    expect(user?.role, UserRole.client);

    expect(tester.takeException(), isNull);
    await unmountFront(tester);
    restore();
  });

  testWidgets('mot de passe oublié', (tester) async {
    final restore = ignoreOfflineImageErrors();
    final app = await pumpFront(tester, location: FrontRoutes.login);
    await tester.tap(find.text('Mot de passe oublié ?'));
    await settle(tester);
    expect(app.path, FrontRoutes.forgotPassword);

    await tester.enterText(find.byType(TextField), 'alex.martin@exemple.fr');
    await tester.tap(find.text('Envoyer le lien'));
    await settle(tester, 1500);
    expect(find.text('E-mail envoyé !'), findsOneWidget);
    await tester.tap(find.text('Retour à la connexion'));
    await settle(tester);
    expect(app.path, FrontRoutes.login);

    expect(tester.takeException(), isNull);
    await unmountFront(tester);
    restore();
  });
}
