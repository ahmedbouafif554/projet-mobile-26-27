import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/core/theme/theme_mode_provider.dart';
import 'package:superfaster/front_office/modules/auth/presentation/widgets/address_card.dart';
import 'package:superfaster/front_office/modules/auth/providers/settings_providers.dart';
import 'package:superfaster/front_office/router/front_routes.dart';

import '../test_helpers.dart';
import 'front_test_utils.dart';

/// Écrans du compte (module 1) : profil, modification, adresses, paramètres.
void main() {
  setUpAll(setUpAppTestEnvironment);

  testWidgets('modifier le profil met à jour la session', (tester) async {
    final restore = ignoreOfflineImageErrors();
    final app = await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.profile,
    );
    // Chiffres clés du client.
    expect(find.text('Commandes'), findsWidgets);
    expect(find.text('340'), findsOneWidget); // points fidélité

    await tester.tap(find.text('Informations personnelles'));
    await settle(tester);
    expect(app.path, FrontRoutes.editProfile);
    await tester.enterText(find.byType(TextField).first, 'Alexandre');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);

    expect(app.path, FrontRoutes.profile);
    expect(find.text('Alexandre Martin'), findsOneWidget);
    expect(
      app.container.read(authServiceProvider).user?.firstName,
      'Alexandre',
    );

    expect(tester.takeException(), isNull);
    await settle(tester, 3000);
    await unmountFront(tester);
    restore();
  });

  testWidgets('adresses : ajouter, définir par défaut, supprimer', (
    tester,
  ) async {
    final restore = ignoreOfflineImageErrors();
    await pumpFront(
      tester,
      userId: 'u-client-1',
      location: FrontRoutes.addresses,
    );
    expect(find.byType(AddressCard), findsNWidgets(3));

    // Ajouter
    await tester.tap(find.text('Ajouter'));
    await settle(tester, 800);
    final form = find.byType(TextField);
    await tester.enterText(form.at(0), 'Chez Léa');
    await tester.enterText(form.at(1), '4 rue du Temple');
    await tester.enterText(form.at(2), '75004');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(find.byType(AddressCard), findsNWidgets(4));
    expect(find.text('Chez Léa'), findsOneWidget);
    await settle(tester, 3000);

    // Définir « Chez Léa » par défaut : elle passe en tête.
    final leaCard = find.ancestor(
      of: find.text('Chez Léa'),
      matching: find.byType(AddressCard),
    );
    await tester.tap(
      find.descendant(of: leaCard, matching: find.byTooltip('Actions')),
    );
    await settle(tester, 400);
    await tester.tap(find.text('Définir par défaut'));
    await settle(tester);
    expect(
      tester.getTopLeft(find.text('Chez Léa')).dy,
      lessThan(tester.getTopLeft(find.text('Maison')).dy),
    );

    // Supprimer (menu + confirmation)
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Bureau'),
          matching: find.byType(AddressCard),
        ),
        matching: find.byTooltip('Actions'),
      ),
    );
    await settle(tester, 400);
    await tester.tap(find.text('Supprimer'));
    await settle(tester, 600);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);
    expect(find.byType(AddressCard), findsNWidgets(3));
    expect(find.text('Bureau'), findsNothing);

    expect(tester.takeException(), isNull);
    await settle(tester, 3000);
    await unmountFront(tester);
    restore();
  });

  testWidgets('paramètres : thème et langue', (tester) async {
    final restore = ignoreOfflineImageErrors();
    final app = await pumpFront(
      tester,
      userId: 'u-courier-1',
      location: FrontRoutes.courierProfile,
    );
    // Profil livreur : courses, note et gains ; pas d'adresses.
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Mes adresses'), findsNothing);

    await tester.tap(find.text('Paramètres'));
    await settle(tester);
    expect(app.path, FrontRoutes.settings);

    await tester.tap(find.text('Sombre'));
    await settle(tester, 800);
    expect(app.container.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.textContaining('English'));
    await settle(tester, 600);
    expect(app.container.read(languageProvider), AppLanguage.en);
    expect(find.textContaining('Traduction à venir'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await settle(tester, 3000);
    await unmountFront(tester);
    restore();
  });

  testWidgets(
    'page du compte ouverte directement : « Retour » mène au profil',
    (tester) async {
      final restore = ignoreOfflineImageErrors();
      final app = await pumpFront(
        tester,
        userId: 'u-courier-1',
        location: FrontRoutes.settings,
      );
      await tester.tap(find.byTooltip('Retour'));
      await settle(tester);
      expect(app.path, FrontRoutes.courierProfile);

      expect(tester.takeException(), isNull);
      await unmountFront(tester);
      restore();
    },
  );
}
