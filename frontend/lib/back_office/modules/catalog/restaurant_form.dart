import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/mock/mock_images.dart';
import '../../../shared/models/models.dart';
import 'catalog_controllers.dart';

/// Création ([restaurant] null, admin) ou modification d'un restaurant
/// (admin, ou restaurateur pour « Mon restaurant »).
Future<bool> openRestaurantForm(
  BuildContext context, {
  Restaurant? restaurant,
}) => showAppForm(context, RestaurantForm(restaurant: restaurant));

/// Valide un nombre décimal (« 2,5 » accepté).
String? decimalValidator(String? value, {bool allowZero = true}) {
  final parsed = parseDecimal(value);
  if (parsed == null) return 'Nombre attendu';
  if (parsed < 0 || (!allowZero && parsed == 0)) return 'Valeur invalide';
  return null;
}

double? parseDecimal(String? value) =>
    double.tryParse((value ?? '').trim().replaceAll(',', '.'));

/// Montant affiché dans un champ (« 2,5 »).
String decimalText(num value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : '$value'.replaceAll('.', ',');

class RestaurantForm extends ConsumerStatefulWidget {
  const RestaurantForm({super.key, this.restaurant});

  final Restaurant? restaurant;

  @override
  ConsumerState<RestaurantForm> createState() => _RestaurantFormState();
}

class _RestaurantFormState extends ConsumerState<RestaurantForm> {
  late final Restaurant? _r = widget.restaurant;
  late final _name = TextEditingController(text: _r?.name);
  late final _description = TextEditingController(text: _r?.description);
  late final _cuisine = TextEditingController(text: _r?.cuisine);
  late final _image = TextEditingController(
    text: _r?.imageUrl ?? unsplash('1517248135467-4c7edcad34c4'),
  );
  late final _address = TextEditingController(text: _r?.address);
  late final _phone = TextEditingController(text: _r?.phone);
  late final _minutes = TextEditingController(
    text: '${_r?.deliveryMinutes ?? 30}',
  );
  late final _fee = TextEditingController(
    text: decimalText(_r?.deliveryFee ?? 1.99),
  );
  late final _minOrder = TextEditingController(
    text: decimalText(_r?.minOrder ?? 10),
  );
  late final _sections = TextEditingController(
    text: _r?.menuSections.join(', ') ?? 'Plats, Desserts, Boissons',
  );
  late final _promo = TextEditingController(text: _r?.promo);

  /// Photo de la carte (data URI de l'image choisie sur le téléphone).
  late String? _menuImage = _r?.menuImageUrl;
  late final Set<String> _categoryIds = {...?_r?.categoryIds};
  late bool _isOpen = _r?.isOpen ?? true;
  late bool _isPopular = _r?.isPopular ?? false;
  late RestaurantStatus _status = _r?.status ?? RestaurantStatus.approved;

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _cuisine,
      _image,
      _address,
      _phone,
      _minutes,
      _fee,
      _minOrder,
      _sections,
      _promo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final base =
        _r ??
        Restaurant(
          id: '',
          name: '',
          description: '',
          cuisine: '',
          categoryIds: const [],
          imageUrl: '',
          address: '',
          phone: '',
          createdAt: DateTime.now(),
        );
    final promo = _promo.text.trim();
    await ref
        .read(restaurantsControllerProvider.notifier)
        .save(
          base.copyWith(
            name: _name.text.trim(),
            description: _description.text.trim(),
            cuisine: _cuisine.text.trim(),
            imageUrl: _image.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            deliveryMinutes: int.tryParse(_minutes.text.trim()) ?? 30,
            deliveryFee: parseDecimal(_fee.text) ?? 0,
            minOrder: parseDecimal(_minOrder.text) ?? 0,
            menuSections: [
              for (final s in _sections.text.split(','))
                if (s.trim().isNotEmpty) s.trim(),
            ],
            menuImageUrl: _menuImage,
            categoryIds: _categoryIds.toList(),
            promo: promo.isEmpty ? null : promo,
            isOpen: _isOpen,
            isPopular: _isPopular,
            status: _status,
          ),
          isNew: _r == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _r == null;
    final isAdmin = ref
        .watch(authServiceProvider)
        .can(Permission.manageRestaurants);
    final categories = ref.watch(categoriesControllerProvider).value ?? [];

    return AppForm(
      title: isNew ? 'Nouveau restaurant' : 'Modifier le restaurant',
      subtitle: isNew ? null : _r.name,
      icon: isNew ? Icons.add_business_rounded : Icons.storefront_rounded,
      successMessage: isNew ? 'Restaurant créé' : 'Restaurant mis à jour',
      onSubmit: _save,
      children: [
        const AppFormSection(title: 'Présentation'),
        AppTextField(
          controller: _name,
          label: 'Nom du restaurant',
          validator: Validators.name,
        ),
        AppTextField(
          controller: _cuisine,
          label: 'Cuisine',
          hint: 'Burgers • Américain',
          validator: (v) => Validators.required(v, field: 'La cuisine'),
        ),
        AppTextField(
          controller: _description,
          label: 'Description',
          maxLines: 3,
          validator: (v) => Validators.required(v, field: 'La description'),
        ),
        ImageUrlField(controller: _image),
        // Toujours présent (même pendant le chargement) : un bloc qui
        // apparaît après coup décalerait les champs suivants du formulaire.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catégories', style: context.text.labelLarge),
            const SizedBox(height: AppSizes.sm),
            if (categories.isEmpty)
              Text('Chargement des catégories…', style: context.text.bodySmall),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final c in categories)
                  FilterChip(
                    label: Text('${c.emoji} ${c.name}'),
                    selected: _categoryIds.contains(c.id),
                    onSelected: (on) => setState(
                      () => on
                          ? _categoryIds.add(c.id)
                          : _categoryIds.remove(c.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const AppFormSection(title: 'Coordonnées'),
        // Adresse et téléphone : chacun sur sa propre ligne.
        AppTextField(
          controller: _address,
          label: 'Adresse',
          prefixIcon: Icons.place_outlined,
          keyboardType: TextInputType.streetAddress,
          validator: (v) => Validators.required(v, field: "L'adresse"),
        ),
        AppTextField(
          controller: _phone,
          label: 'Téléphone',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: Validators.phone,
        ),
        const AppFormSection(title: 'Livraison'),
        AppFormRow(
          children: [
            AppTextField(
              controller: _minutes,
              label: 'Délai (min)',
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) <= 0
                  ? 'Durée invalide'
                  : null,
            ),
            AppTextField(
              controller: _fee,
              label: 'Frais (€)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: decimalValidator,
            ),
            AppTextField(
              controller: _minOrder,
              label: 'Minimum (€)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: decimalValidator,
            ),
          ],
        ),
        const AppFormSection(title: 'Menu et offre'),
        MenuPhotoField(
          value: _menuImage,
          onChanged: (image) => setState(() => _menuImage = image),
        ),
        AppTextField(
          controller: _sections,
          label: 'Onglets du menu',
          hint: 'Burgers, Accompagnements, Boissons',
          validator: (v) => Validators.required(v, field: 'Le menu'),
        ),
        AppTextField(
          controller: _promo,
          label: 'Offre en cours (facultatif)',
          hint: '-20 % sur tout le menu',
          prefixIcon: Icons.local_offer_outlined,
        ),
        AppSwitchField(
          title: 'Ouvert aux commandes',
          subtitle: 'Fermé, le restaurant reste visible mais grisé.',
          icon: Icons.door_front_door_outlined,
          value: _isOpen,
          onChanged: (v) => setState(() => _isOpen = v),
        ),
        if (isAdmin) ...[
          AppSwitchField(
            title: 'Mis en avant',
            subtitle: 'Affiché dans « Populaires » sur l’accueil.',
            icon: Icons.local_fire_department_outlined,
            value: _isPopular,
            onChanged: (v) => setState(() => _isPopular = v),
          ),
          AppDropdownField<RestaurantStatus>(
            label: 'Statut',
            value: _status,
            items: RestaurantStatus.values,
            itemLabel: (s) => s.label,
            onChanged: (s) => setState(() => _status = s ?? _status),
          ),
        ],
      ],
    );
  }
}

/// Photo du menu importée depuis le téléphone : galerie ou appareil photo,
/// avec aperçu, remplacement et suppression. L'image est gardée en data URI
/// (`data:image/jpeg;base64,…`) et enregistrée avec le restaurant.
class MenuPhotoField extends StatefulWidget {
  const MenuPhotoField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Limite de l'image une fois compressée (le serveur accepte ~2 Mo).
  static const maxBytes = 2000000;

  @override
  State<MenuPhotoField> createState() => _MenuPhotoFieldState();
}

class _MenuPhotoFieldState extends State<MenuPhotoField> {
  bool _loading = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _loading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 75,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > MenuPhotoField.maxBytes) {
        AppSnackbar.error(context, 'Photo trop lourde (2 Mo maximum).');
        return;
      }
      widget.onChanged(
        'data:${_mimeOf(file, bytes)};base64,${base64Encode(bytes)}',
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Impossible de lire cette photo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Type de l'image (JPEG par défaut, PNG et WebP reconnus).
  static String _mimeOf(XFile file, Uint8List bytes) {
    final declared = file.mimeType;
    if (declared != null && declared.startsWith('image/')) return declared;
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return 'image/png';
    }
    if (bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.value;
    final hasImage = image != null && image.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo du menu', style: context.text.labelLarge),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Importez une photo de votre carte depuis votre téléphone.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSizes.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: Container(
            height: 180,
            width: double.infinity,
            color: context.colors.surfaceContainerHighest,
            alignment: Alignment.center,
            child: _loading
                ? const CircularProgressIndicator()
                : hasImage
                ? AppNetworkImage(
                    image,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    fallbackIcon: Icons.menu_book_rounded,
                  )
                : Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: context.colors.onSurfaceVariant,
                  ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                hasImage ? 'Changer la photo' : 'Choisir dans la galerie',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Prendre une photo'),
            ),
            if (hasImage)
              TextButton.icon(
                onPressed: _loading ? null : () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Retirer'),
              ),
          ],
        ),
      ],
    );
  }
}

/// URL de l'image avec aperçu (restaurants et produits).
class ImageUrlField extends StatefulWidget {
  const ImageUrlField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<ImageUrlField> createState() => _ImageUrlFieldState();
}

class _ImageUrlFieldState extends State<ImageUrlField> {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: AppNetworkImage(
            widget.controller.text.trim(),
            width: 76,
            height: 76,
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: AppTextField(
            controller: widget.controller,
            label: "URL de l'image",
            prefixIcon: Icons.image_outlined,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            validator: (v) => Uri.tryParse(v?.trim() ?? '')?.hasScheme == true
                ? null
                : 'URL invalide',
          ),
        ),
      ],
    );
  }
}
