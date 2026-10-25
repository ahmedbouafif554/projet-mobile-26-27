import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/core/theme/theme_mode_provider.dart';
import 'package:superfaster/front_office/front_app.dart';
import 'package:superfaster/front_office/router/front_router.dart';
import 'package:superfaster/shared/mock/mock_users.dart';

import '../test_helpers.dart';

/// Application front office montée pour un test, avec son conteneur
/// Riverpod (données mock neuves à chaque test).
class FrontHarness {
  FrontHarness(this.container);

  final ProviderContainer container;

  GoRouter get router => container.read(frontRouterProvider);

  /// Chemin de l'écran affiché, y compris un écran empilé par `push`
  /// (ex. `/account/edit`).
  String get path => router.state.uri.path;

  void go(String location) => router.go(location);
}

/// Monte le front office. [userId] : utilisateur déjà connecté
/// (ex. `u-client-1`), [location] : écran à ouvrir.
Future<FrontHarness> pumpFront(
  WidgetTester tester, {
  String? userId,
  String? location,
  Size size = const Size(390, 844),
  ThemeMode mode = ThemeMode.light,
}) async {
  useScreenSize(tester, size);
  final container = ProviderContainer(retry: (_, _) => null);
  addTearDown(container.dispose);
  container.read(themeModeProvider.notifier).set(mode);
  if (userId != null) {
    // Ouvre la session sans délai (évite les attentes asynchrones du test).
    container
        .read(authServiceProvider.notifier)
        .updateUser(MockUsers.byId(userId));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FrontOfficeApp(),
    ),
  );
  final harness = FrontHarness(container);
  if (location != null) harness.go(location);
  await settle(tester, 1200);
  return harness;
}

/// Démonte l'application en laissant finir les animations en cours.
Future<void> unmountFront(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester, 600);
}

/// Texte d'un onglet de la barre de navigation.
Finder navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Fait défiler la page affichée jusqu'à [finder] (plusieurs listes
/// coexistent : une par onglet). `scrollUntilVisible` s'arrête dès que
/// l'élément est construit : `ensureVisible` l'amène vraiment à l'écran.
Future<void> scrollTo(WidgetTester tester, Finder finder, Type page) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(of: find.byType(page), matching: find.byType(Scrollable))
        .first,
  );
  await tester.ensureVisible(finder);
  await settle(tester, 300);
}
