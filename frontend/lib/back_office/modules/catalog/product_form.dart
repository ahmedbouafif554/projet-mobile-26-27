import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/mock/mock_images.dart';
import '../../../shared/models/models.dart';
import 'catalog_controllers.dart';
import 'restaurant_form.dart';

/// Création ([product] null) ou modification d'un produit. Un restaurateur
/// ne gère que son menu ; l'admin choisit le restaurant.
Future<bool> openProductForm(BuildContext context, {Product? product}) =>
    showAppForm(context, ProductForm(product: product));

class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
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
  late String? _restaurantId =
      _p?.restaurantId ?? ref.read(productsControllerProvider.notifier).scope;
  late String? _section = _p?.section;
  late String? _categoryId = _p?.categoryId;
  late bool _available = _p?.isAvailable ?? true;
  late bool _popular = _p?.isPopular ?? false;

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _image, _calories]) {
      c.dispose();
    }
    super.dispose();
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
    final sections = {
      ...?restaurant?.menuSections,
      ?_p?.section,
    }.toList();

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
