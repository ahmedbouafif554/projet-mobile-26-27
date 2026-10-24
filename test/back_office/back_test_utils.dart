import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:superfaster/back_office/back_app.dart';
import 'package:superfaster/back_office/router/back_router.dart';
import 'package:superfaster/core/auth/auth_service.dart';
import 'package:superfaster/core/theme/theme_mode_provider.dart';
import 'package:superfaster/shared/mock/mock_users.dart';

import '../test_helpers.dart';

/// Back office monté pour un test, avec son conteneur Riverpod (données
/// mock neuves à chaque test).
class BackHarness {
  BackHarness(this.container);

  final ProviderContainer container;

  GoRouter get router => container.read(backRouterProvider);

  String get path => router.state.uri.path;

  void go(String location) => router.go(location);

  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  /// Valeur chargée d'un fournisseur asynchrone. Les délais mock ne
  /// s'écoulent qu'en faisant avancer le temps du test : on écoute le
  /// fournisseur et on avance de quelques images au lieu d'attendre son
  /// `future` (qui ne se terminerait jamais).
  Future<T> loaded<T>(
    WidgetTester tester,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    final subscription = container.listen(provider, (_, _) {});
    await settle(tester, 300);
    final value = subscription.read().value as T;
    subscription.close();
    return value;
  }
}

/// Monte le back office. [userId] : compte déjà connecté (`u-admin`,
/// `u-resto-1`), [location] : page à ouvrir.
Future<BackHarness> pumpBack(
  WidgetTester tester, {
  String? userId,
  String? location,
  Size size = const Size(1440, 900),
  ThemeMode mode = ThemeMode.light,
}) async {
  useScreenSize(tester, size, ratio: 1);
  final container = ProviderContainer(retry: (_, _) => null);
  addTearDown(container.dispose);
  container.read(themeModeProvider.notifier).set(mode);
  if (userId != null) {
    container
        .read(authServiceProvider.notifier)
        .updateUser(MockUsers.byId(userId));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const BackOfficeApp(),
    ),
  );
  final harness = BackHarness(container);
  if (location != null) harness.go(location);
  await settle(tester, 1500);
  return harness;
}

/// Démonte l'application en laissant finir les animations en cours.
Future<void> unmountBack(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester, 600);
}

/// Ouvre le menu « ⋮ » de la ligne du tableau qui contient [rowText], puis
/// choisit [action].
Future<void> tapRowAction(
  WidgetTester tester,
  String rowText,
  String action,
) async {
  final rows = find.ancestor(
    of: find.text(rowText).first,
    matching: find.byType(InkWell),
  );
  // Ligne la plus proche qui possède un menu d'actions.
  Finder? menu;
  for (final element in rows.evaluate()) {
    final candidate = find.descendant(
      of: find.byElementPredicate((e) => e == element),
      matching: find.byIcon(Icons.more_vert_rounded),
    );
    if (candidate.evaluate().isNotEmpty) {
      menu = candidate.first;
      break;
    }
  }
  expect(menu, isNotNull, reason: 'Pas de menu pour « $rowText »');
  await tester.ensureVisible(menu!);
  await tester.tap(menu);
  await settle(tester, 600);
  await tester.tap(find.text(action).last);
  await settle(tester, 800);
}
