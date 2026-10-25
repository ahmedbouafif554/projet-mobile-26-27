import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/theme/theme_mode_provider.dart';
import 'package:superfaster/dev/component_gallery.dart';

import '../test_helpers.dart';

/// Test de fumée du catalogue de composants (étape 1) : tout s'affiche sans
/// erreur ni débordement, en clair et en sombre, sur téléphone et grand écran.
void main() {
  setUpAll(setUpAppTestEnvironment);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in const [Size(390, 844), Size(1280, 900)]) {
      testWidgets('catalogue (${mode.name}, ${size.width.toInt()} px)', (
        tester,
      ) async {
        useScreenSize(tester, size);
        final restore = ignoreOfflineImageErrors();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(themeModeProvider.notifier).set(mode);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const ComponentGalleryApp(title: 'SuperFaster'),
          ),
        );
        await settle(tester, 2000);
        expect(find.text('Composants SuperFaster'), findsOneWidget);
        expect(find.text('Commandes du jour'), findsOneWidget);

        // Le tableau est plus bas (trié du plus récent au plus ancien).
        await tester.scrollUntilVisible(
          find.text('Sarah Dupont'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester, 600);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        restore();
      });
    }
  }

  testWidgets('créer un utilisateur depuis le formulaire', (tester) async {
    useScreenSize(tester, const Size(1280, 900));
    final restore = ignoreOfflineImageErrors();
    await tester.pumpWidget(
      const ProviderScope(child: ComponentGalleryApp(title: 'SuperFaster')),
    );
    await settle(tester, 1500);

    await tester.tap(find.text('Nouvel utilisateur'));
    await settle(tester, 800);
    final fields = find.descendant(
      of: find.byType(UserForm),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Nina');
    await tester.enterText(fields.at(1), 'Simon');
    await tester.enterText(fields.at(2), 'nina.simon@exemple.fr');
    await tester.enterText(fields.at(3), '06 11 22 33 44');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester, 1500);

    expect(find.text('Utilisateur créé'), findsOneWidget);
    // Le nouvel utilisateur est le plus récent : en tête du tableau.
    await tester.scrollUntilVisible(
      find.text('Nina Simon'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nina Simon'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await settle(tester, 3500);
    await tester.pumpWidget(const SizedBox());
    restore();
  });
}
