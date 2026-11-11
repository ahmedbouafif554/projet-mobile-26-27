import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/location/geocoding_service.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_form.dart';
import '../../../../../core/widgets/app_form_fields.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../../shared/models/address.dart';
import '../../providers/addresses_controller.dart';
import 'address_card.dart';
import 'address_map_field.dart';

/// Ouvre le formulaire d'adresse : création ([address] null) ou modification.
Future<bool> openAddressForm(BuildContext context, {Address? address}) =>
    showAppForm(context, AddressForm(address: address));

class AddressForm extends ConsumerStatefulWidget {
  const AddressForm({super.key, this.address});

  final Address? address;

  @override
  ConsumerState<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<AddressForm> {
  late final _label = TextEditingController(text: widget.address?.label);
  late final _street = TextEditingController(text: widget.address?.street);
  late final _postalCode = TextEditingController(
    text: widget.address?.postalCode,
  );
  late final _city = TextEditingController(
    text: widget.address?.city ?? 'Paris',
  );
  late final _instructions = TextEditingController(
    text: widget.address?.instructions,
  );
  late AddressType _type = widget.address?.type ?? AddressType.home;
  late bool _isDefault = widget.address?.isDefault ?? false;

  /// Position exacte placée sur la carte. Une adresse encore aux coordonnées
  /// par défaut (centre de Paris) n'a jamais été placée : à placer.
  late LatLng? _position = _placedPosition(widget.address);

  static LatLng? _placedPosition(Address? a) {
    if (a == null) return null;
    final isDefault =
        a.latitude == AddressMapField.fallbackCenter.latitude &&
        a.longitude == AddressMapField.fallbackCenter.longitude;
    return isDefault ? null : LatLng(a.latitude, a.longitude);
  }

  /// Adresse trouvée sur la carte → champs du formulaire.
  void _fillFrom(GeocodedAddress found) => setState(() {
    if (found.street.isNotEmpty) _street.text = found.street;
    if (found.postalCode.isNotEmpty) _postalCode.text = found.postalCode;
    if (found.city.isNotEmpty) _city.text = found.city;
  });

  String _typedAddress() => [
    _street.text.trim(),
    _postalCode.text.trim(),
    _city.text.trim(),
  ].where((s) => s.isNotEmpty).join(', ');

  @override
  void dispose() {
    for (final c in [_label, _street, _postalCode, _city, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() {
    final base =
        widget.address ??
        const Address(
          id: '',
          userId: '',
          label: '',
          street: '',
          postalCode: '',
          city: '',
        );
    final instructions = _instructions.text.trim();
    return ref
        .read(addressesProvider.notifier)
        .save(
          base.copyWith(
            label: _label.text.trim().isEmpty
                ? _type.label
                : _label.text.trim(),
            street: _street.text.trim(),
            postalCode: _postalCode.text.trim(),
            city: _city.text.trim(),
            type: _type,
            instructions: instructions.isEmpty ? null : instructions,
            isDefault: _isDefault,
            // Validé par le formulaire : la position est toujours placée ici.
            latitude: _position?.latitude,
            longitude: _position?.longitude,
          ),
        );
  }

  static String? _postalCodeValidator(String? value) {
    final digits = value?.trim() ?? '';
    if (digits.isEmpty) return 'Le code postal est obligatoire';
    if (!RegExp(r'^\d{5}$').hasMatch(digits)) return 'Code postal invalide';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.address == null;
    return AppForm(
      title: isNew ? 'Nouvelle adresse' : "Modifier l'adresse",
      icon: Icons.add_location_alt_rounded,
      successMessage: isNew ? 'Adresse ajoutée' : 'Adresse modifiée',
      onSubmit: _save,
      children: [
        const AppFormSection(title: 'Type'),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final type in AddressType.values)
              SelectableChip(
                label: type.label,
                icon: addressIcon(type),
                selected: _type == type,
                onTap: () => setState(() => _type = type),
              ),
          ],
        ),
        AppTextField(
          controller: _label,
          label: 'Nom (facultatif)',
          hint: 'Maison, Chez Léa…',
          prefixIcon: Icons.label_outline_rounded,
          textCapitalization: TextCapitalization.sentences,
        ),
        AppTextField(
          controller: _street,
          label: 'Adresse',
          hint: '12 rue de la Paix',
          prefixIcon: Icons.place_outlined,
          validator: (v) => Validators.required(v, field: "L'adresse"),
        ),
        AppFormRow(
          children: [
            AppTextField(
              controller: _postalCode,
              label: 'Code postal',
              keyboardType: TextInputType.number,
              maxLength: 5,
              validator: _postalCodeValidator,
            ),
            AppTextField(
              controller: _city,
              label: 'Ville',
              validator: (v) => Validators.required(v, field: 'La ville'),
            ),
          ],
        ),
        AddressMapField(
          initial: _position,
          onChanged: (p) => _position = p,
          onAddressFound: _fillFrom,
          searchQuery: _typedAddress,
        ),
        AppTextField(
          controller: _instructions,
          label: 'Instructions (facultatif)',
          hint: 'Digicode, étage…',
          prefixIcon: Icons.notes_rounded,
          maxLines: 2,
        ),
        AppSwitchField(
          title: 'Adresse par défaut',
          subtitle: 'Utilisée pour vos prochaines commandes',
          icon: Icons.star_outline_rounded,
          value: _isDefault,
          onChanged: (v) => setState(() => _isDefault = v),
        ),
      ],
    );
  }
}
