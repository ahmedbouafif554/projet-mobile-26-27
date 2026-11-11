import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/back_office/modules/catalog/restaurant_form.dart';
import 'package:superfaster/core/theme/app_theme.dart';
import 'package:superfaster/core/widgets/app_form.dart';
import 'package:superfaster/core/widgets/app_text_field.dart';

/// Champ texte (EditableText) d'un AppTextField repéré par son libellé.
Finder _input(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(AppTextField)),
  matching: find.byType(EditableText),
);

String _shown(WidgetTester tester, String label) =>
    tester.widget<EditableText>(_input(label)).controller.text;

/// Reproduit la fiche restaurant : un bloc (les catégories) apparaît au-dessus
/// des coordonnées une fois chargé, dans un AppForm animé.
class _LateBlockForm extends StatefulWidget {
  const _LateBlockForm({required this.address, required this.phone});

  final TextEditingController address;
  final TextEditingController phone;

  @override
  State<_LateBlockForm> createState() => _LateBlockFormState();
}

class _LateBlockFormState extends State<_LateBlockForm> {
  bool loaded = false;

  void load() => setState(() => loaded = true);

  @override
  Widget build(BuildContext context) => AppForm(
    title: 'Nouveau restaurant',
    onSubmit: () async {},
    children: [
      const AppTextField(label: 'Nom du restaurant'),
      if (loaded) const Text('Catégories'),
      const Text('Coordonnées'),
      AppTextField(controller: widget.address, label: 'Adresse'),
      AppTextField(controller: widget.phone, label: 'Téléphone'),
    ],
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'un bloc qui apparaît plus haut ne lie pas Adresse et Téléphone',
    (tester) async {
      final address = TextEditingController();
      final phone = TextEditingController();
      addTearDown(address.dispose);
      addTearDown(phone.dispose);
      await _pump(tester, _LateBlockForm(address: address, phone: phone));

      // Les catégories arrivent : tous les champs suivants changent de place.
      tester.state<_LateBlockFormState>(find.byType(_LateBlockForm)).load();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(_input('Adresse'), '12 rue de la Paix, Paris');
      await tester.pump();
      await tester.enterText(_input('Téléphone'), '+33 6 12 34 56 78');
      await tester.pump();

      // Chaque champ affiche et enregistre sa propre valeur.
      expect(_shown(tester, 'Adresse'), '12 rue de la Paix, Paris');
      expect(_shown(tester, 'Téléphone'), '+33 6 12 34 56 78');
      expect(address.text, '12 rue de la Paix, Paris');
      expect(phone.text, '+33 6 12 34 56 78');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('fiche restaurant : Adresse et Téléphone indépendants', (
    tester,
  ) async {
    await _pump(tester, const RestaurantForm());

    await tester.enterText(_input('Adresse'), '12 rue de la Paix, Paris');
    await tester.pump();
    expect(_shown(tester, 'Téléphone'), isEmpty);
    await tester.enterText(_input('Téléphone'), '+33 6 12 34 56 78');
    await tester.pump();
    expect(_shown(tester, 'Adresse'), '12 rue de la Paix, Paris');
    expect(_shown(tester, 'Téléphone'), '+33 6 12 34 56 78');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
