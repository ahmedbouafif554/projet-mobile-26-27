import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/mock/mock_images.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/repository_providers.dart';
import 'catalog_controllers.dart';
import 'restaurant_form.dart';

/// Création ([product] null) ou modification d'un produit. Un restaurateur
/// ne gère que son menu ; l'admin choisit le restaurant. Un code-barres
/// pré-remplit la fiche depuis Open Food Facts.
Future<bool> openProductForm(BuildContext context, {Product? product}) =>
    showAppForm(context, ProductForm(product: product));

class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  static const _invalidBarcode =
      'Code-barres invalide : 8, 12, 13 ou 14 chiffres.';

  late final Product? _p = widget.product;
  late final _name = TextEditingController(text: _p?.name);
  late final _description = TextEditingController(text: _p?.description);
  late final _price = TextEditingController(
    text: _p == null ? '' : decimalText(_p.price),
  );
  late final _image = TextEditingController(
    text: _p?.imageUrl ?? unsplash('1504674900247-0877df9cc836'),
  );
  late final _calories = TextEditingController(
    text: _p?.calories?.toString() ?? '',
  );
  late final _barcode = TextEditingController(text: _p?.barcode ?? '');
  late String? _restaurantId =
      _p?.restaurantId ?? ref.read(productsControllerProvider.notifier).scope;
  late String? _section = _p?.section;
  late String? _categoryId = _p?.categoryId;
  late NutriScore? _nutriScore = _p?.nutriScore;
  late final Set<String> _allergens = {...?_p?.allergens};
  late bool _available = _p?.isAvailable ?? true;
  late bool _popular = _p?.isPopular ?? false;

  bool _lookingUp = false;
  String? _lookupMessage;
  bool _lookupFailed = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _price,
      _image,
      _calories,
      _barcode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pré-remplit la fiche depuis Open Food Facts (le serveur interroge la
  /// base et garde la réponse en cache). Rien n'est enregistré ici.
  Future<void> _lookUpBarcode() async {
    if (_lookingUp) return;
    final code = _barcode.text.trim();
    if (!isValidBarcode(code)) {
      setState(() {
        _lookupFailed = true;
        _lookupMessage = _invalidBarcode;
      });
      return;
    }
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
    });
    try {
      final found = await ref
          .read(productRepositoryProvider)
          .lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        _barcode.text = found.barcode;
        if (found.name.isNotEmpty) _name.text = found.name;
        if (found.description.isNotEmpty) {
          _description.text = found.description;
        }
        if (found.imageUrl.isNotEmpty) _image.text = found.imageUrl;
        if (found.calories != null) _calories.text = '${found.calories}';
        if (found.nutriScore != null) _nutriScore = found.nutriScore;
        _allergens
          ..clear()
          ..addAll(found.allergens);
        _lookupFailed = false;
        final per100g = found.caloriesPer100g && found.calories != null
            ? ' (calories pour 100 g)'
            : '';
        _lookupMessage =
            'Fiche importée depuis Open Food Facts$per100g : '
            'vérifiez-la avant d’enregistrer.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _lookupFailed = true;
        _lookupMessage = switch (error.statusCode) {
          404 =>
            'Aucun produit trouvé pour ce code-barres sur Open Food Facts.',
          422 => _invalidBarcode,
          502 || 503 || 504 =>
            'Open Food Facts ne répond pas, réessayez dans un instant.',
          _ => error.message,
        };
      });
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _save() {
    final base =
        _p ??
        Product(
          id: '',
          restaurantId: '',
          categoryId: '',
          name: '',
          description: '',
          price: 0,
          imageUrl: '',
          section: '',
        );
    final calories = int.tryParse(_calories.text.trim());
    final barcode = _barcode.text.replaceAll(RegExp(r'[\s-]'), '');
    return ref
        .read(productsControllerProvider.notifier)
        .save(
          base.copyWith(
            restaurantId: _restaurantId,
            categoryId: _categoryId ?? '',
            name: _name.text.trim(),
            description: _description.text.trim(),
            price: parseDecimal(_price.text),
            imageUrl: _image.text.trim(),
            section: _section,
            calories: calories,
            barcode: barcode.isEmpty ? null : barcode,
            nutriScore: _nutriScore,
            // Ordre officiel de la liste des allergènes.
            allergens: [
              for (final code in Allergens.labels.keys)
                if (_allergens.contains(code)) code,
            ],
            isAvailable: _available,
            isPopular: _popular,
          ),
          isNew: _p == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _p == null;
    final isRestaurateur =
        ref.watch(authServiceProvider).role == UserRole.restaurant;
    final restaurants = ref.watch(restaurantsControllerProvider).value ?? [];
    final categories = ref.watch(categoriesControllerProvider).value ?? [];
    final restaurant = restaurants
        .where((r) => r.id == _restaurantId)
        .firstOrNull;
    final sections = {...?restaurant?.menuSections, ?_p?.section}.toList();

    return AppForm(
      title: isNew ? 'Nouveau produit' : 'Modifier le produit',
      subtitle: isNew ? restaurant?.name : _p.name,
      icon: isNew ? Icons.add_box_rounded : Icons.fastfood_rounded,
      successMessage: isNew ? 'Produit ajouté au menu' : 'Produit mis à jour',
      onSubmit: _save,
      children: [
        if (!isRestaurateur)
          AppDropdownField<String>(
            label: 'Restaurant',
            prefixIcon: Icons.storefront_outlined,
            value: restaurant?.id,
            items: [for (final r in restaurants) r.id],
            itemLabel: (id) => restaurants.firstWhere((r) => r.id == id).name,
            onChanged: (id) => setState(() {
              _restaurantId = id;
              _section = null;
            }),
            validator: (id) => id == null ? 'Choisissez le restaurant' : null,
          ),
        const AppFormSection(title: 'Produit'),
        AppTextField(
          controller: _barcode,
          label: 'Code-barres EAN (facultatif)',
          hint: 'Ex. 3017620422003, puis Rechercher',
          prefixIcon: Icons.qr_code_2_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _lookUpBarcode(),
          onChanged: (_) {
            if (_lookupMessage != null) setState(() => _lookupMessage = null);
          },
          validator: (v) => (v ?? '').trim().isEmpty || isValidBarcode(v!)
              ? null
              : _invalidBarcode,
          suffix: _lookingUp
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Rechercher sur Open Food Facts',
                  onPressed: _lookUpBarcode,
                  icon: const Icon(Icons.travel_explore_rounded),
                ),
        ),
        if (_lookupMessage != null)
          _LookupMessage(message: _lookupMessage!, failed: _lookupFailed),
        AppTextField(
          controller: _name,
          label: 'Nom',
          validator: Validators.name,
        ),
        AppTextField(
          controller: _description,
          label: 'Description',
          maxLines: 3,
          validator: (v) => Validators.required(v, field: 'La description'),
        ),
        ImageUrlField(controller: _image),
        AppFormRow(
          children: [
            AppTextField(
              controller: _price,
              label: 'Prix (€)',
              prefixIcon: Icons.euro_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => decimalValidator(v, allowZero: false),
            ),
            AppTextField(
              controller: _calories,
              label: 'Calories (facultatif)',
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v ?? '').trim().isEmpty || int.tryParse(v!.trim()) != null
                  ? null
                  : 'Nombre entier attendu',
            ),
          ],
        ),
        const AppFormSection(title: 'Informations alimentaires'),
        AppDropdownField<NutriScore?>(
          // Nouvelle clé quand Open Food Facts remplit la valeur.
          key: ValueKey('nutri-score-${_nutriScore?.name}'),
          label: 'Nutri-Score (facultatif)',
          value: _nutriScore,
          items: const [null, ...NutriScore.values],
          itemLabel: (s) =>
              s == null ? 'Non renseigné' : 'Nutri-Score ${s.letter}',
          onChanged: (s) => setState(() => _nutriScore = s),
        ),
        _AllergenPicker(
          selected: _allergens,
          onToggle: (code) => setState(() {
            if (!_allergens.remove(code)) _allergens.add(code);
          }),
        ),
        const AppFormSection(title: 'Classement'),
        AppFormRow(
          children: [
            AppDropdownField<String>(
              label: 'Onglet du menu',
              value: sections.contains(_section) ? _section : null,
              items: sections,
              itemLabel: (s) => s,
              onChanged: (s) => setState(() => _section = s),
              validator: (s) => s == null ? "Choisissez l'onglet" : null,
            ),
            AppDropdownField<String>(
              label: 'Catégorie',
              value: categories.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              items: [for (final c in categories) c.id],
              itemLabel: (id) {
                final c = categories.firstWhere((c) => c.id == id);
                return '${c.emoji} ${c.name}';
              },
              onChanged: (id) => setState(() => _categoryId = id),
            ),
          ],
        ),
        AppSwitchField(
          title: 'Disponible',
          subtitle: 'Désactivé, le produit apparaît « en rupture ».',
          icon: Icons.inventory_2_outlined,
          value: _available,
          onChanged: (v) => setState(() => _available = v),
        ),
        AppSwitchField(
          title: 'Populaire',
          subtitle: 'Mis en avant en tête du menu.',
          icon: Icons.local_fire_department_outlined,
          value: _popular,
          onChanged: (v) => setState(() => _popular = v),
        ),
      ],
    );
  }
}

/// Résultat de la recherche Open Food Facts, sous le code-barres.
class _LookupMessage extends StatelessWidget {
  const _LookupMessage({required this.message, required this.failed});

  final String message;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed ? AppColors.error : AppColors.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          failed ? Icons.error_outline_rounded : Icons.check_circle_outline,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: context.text.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Les 14 allergènes à déclaration obligatoire, à cocher.
class _AllergenPicker extends StatelessWidget {
  const _AllergenPicker({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sm, left: 2),
        child: Text('Allergènes', style: context.text.labelLarge),
      ),
      Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        children: [
          for (final MapEntry(key: code, value: label)
              in Allergens.labels.entries)
            FilterChip(
              label: Text(label),
              selected: selected.contains(code),
              onSelected: (_) => onToggle(code),
            ),
        ],
      ),
    ],
  );
}
