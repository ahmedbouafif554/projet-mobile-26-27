import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/theme/app_theme.dart';
import 'package:superfaster/core/widgets/app_data_table.dart';
import 'package:superfaster/core/widgets/app_form.dart';
import 'package:superfaster/core/widgets/app_text_field.dart';
import 'package:superfaster/core/widgets/shimmer_box.dart';
import 'package:superfaster/core/widgets/stat_card.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/user.dart';

import '../test_helpers.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Tableau des utilisateurs mock, avec recherche, filtre et actions.
AppDataTable<User> _usersTable({
  List<User>? items,
  bool isLoading = false,
  List<User>? deleted,
}) => AppDataTable<User>(
  items: items,
  isLoading: isLoading,
  searchText: (u) => '${u.fullName} ${u.email}',
  filters: [
    AppTableFilter(
      label: 'Rôle',
      options: {for (final r in UserRole.values) r.name: r.label},
      test: (u, v) => u.role.name == v,
    ),
  ],
  columns: [
    AppTableColumn(
      label: 'Nom',
      primary: true,
      sortValue: (u) => u.fullName,
      cell: (_, u) => Text(u.fullName),
    ),
    AppTableColumn(
      label: 'Rôle',
      sortValue: (u) => u.role.index,
      cell: (_, u) => Text(u.role.label),
    ),
  ],
  onEdit: (_) {},
  onDelete: (u) async => deleted?.add(u),
);

void main() {
  setUpAll(setUpAppTestEnvironment);

  group('AppDataTable', () {
    testWidgets('recherche, filtre, tri, pagination et suppression', (
      tester,
    ) async {
      useScreenSize(tester, const Size(1280, 1600));
      final deleted = <User>[];
      final total = MockUsers.users.length;
      await tester.pumpWidget(
        _app(_usersTable(items: MockUsers.users, deleted: deleted)),
      );
      await settle(tester, 800);
      expect(find.text('1–10 sur $total'), findsOneWidget);

      // Recherche (temporisée)
      await tester.enterText(find.byType(TextField), 'karim');
      await settle(tester, 600);
      expect(find.text('1–1 sur 1'), findsOneWidget);
      expect(find.text('Karim Benali'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer'));
      await settle(tester, 600);

      // Filtre « Rôle : Livreur »
      await tester.tap(find.text('Rôle').first);
      await settle(tester, 400);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Livreur'),
      );
      await settle(tester, 600);
      expect(find.text('1–6 sur 6'), findsOneWidget);
      await tester.tap(find.text('Rôle : Livreur'));
      await settle(tester, 400);
      await tester.tap(find.text('Tous (Rôle)'));
      await settle(tester, 600);

      // Tri par nom (A → Z puis Z → A)
      await tester.tap(find.text('NOM'));
      await settle(tester, 600);
      final sorted = [...MockUsers.users]
        ..sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
      expect(
        tester.getTopLeft(find.text(sorted.first.fullName)).dy,
        lessThan(tester.getTopLeft(find.text(sorted[1].fullName)).dy),
      );

      // Page suivante
      await tester.tap(find.byTooltip('Page suivante'));
      await settle(tester, 600);
      expect(find.text('11–20 sur $total'), findsOneWidget);

      // Suppression avec confirmation
      await tester.tap(find.byTooltip('Supprimer').first);
      await settle(tester, 600);
      expect(find.text('Supprimer cet élément ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await settle(tester, 600);
      expect(deleted, hasLength(1));
      expect(find.text('Élément supprimé'), findsOneWidget);
      await settle(tester, 3500);
    });

    testWidgets('chargement (shimmer), état vide et affichage en cartes', (
      tester,
    ) async {
      useScreenSize(tester, const Size(390, 900));
      await tester.pumpWidget(_app(_usersTable(isLoading: true)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpWidget(_app(_usersTable(items: const [])));
      await settle(tester, 800);
      expect(find.text('Aucun résultat'), findsOneWidget);

      await tester.pumpWidget(_app(_usersTable(items: MockUsers.users)));
      await settle(tester, 800);
      // Petit écran : une carte par ligne, actions dans un menu.
      expect(find.byTooltip('Actions'), findsNWidgets(10));
      expect(find.text('NOM'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('AppForm : validation puis enregistrement', (tester) async {
    useScreenSize(tester, const Size(1280, 900));
    var submitted = 0;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await showAppForm(
                  context,
                  AppForm(
                    title: 'Nouvelle catégorie',
                    successMessage: 'Catégorie créée',
                    onSubmit: () async => submitted++,
                    children: [
                      AppTextField(
                        label: 'Nom',
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Le nom est obligatoire' : null,
                      ),
                    ],
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await settle(tester, 800);
    expect(find.text('Nouvelle catégorie'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await settle(tester, 600);
    expect(find.text('Le nom est obligatoire'), findsOneWidget);
    expect(submitted, 0);

    await tester.enterText(find.byType(TextField), 'Végétarien');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester, 800);
    expect(submitted, 1);
    expect(result, isTrue);
    expect(find.text('Nouvelle catégorie'), findsNothing);
    expect(find.text('Catégorie créée'), findsOneWidget);
    await settle(tester, 3500);
  });

  testWidgets('StatCard : le compteur arrive à sa valeur', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 280,
          child: StatCard(
            label: 'Commandes du jour',
            value: 42,
            icon: Icons.receipt_long_rounded,
            trend: 12.5,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('42'), findsNothing);
    await settle(tester, 1500);
    expect(find.text('42'), findsOneWidget);
  });
}
