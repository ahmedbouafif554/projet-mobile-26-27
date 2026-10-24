import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../users/users_controller.dart';
import 'delivery_controllers.dart';

/// Création ([courier] null) ou modification d'un livreur. La création
/// ouvre aussi son compte utilisateur (rôle livreur).
Future<bool> openCourierForm(BuildContext context, {Courier? courier}) =>
    showAppForm(context, CourierForm(courier: courier));

class CourierForm extends ConsumerStatefulWidget {
  const CourierForm({super.key, this.courier});

  final Courier? courier;

  @override
  ConsumerState<CourierForm> createState() => _CourierFormState();
}

class _CourierFormState extends ConsumerState<CourierForm> {
  late final Courier? _c = widget.courier;
  late final _first = TextEditingController(text: _c?.firstName);
  late final _last = TextEditingController(text: _c?.lastName);
  late final _phone = TextEditingController(text: _c?.phone);
  final _email = TextEditingController();
  late final _plate = TextEditingController(text: _c?.plateNumber);
  late final _zone = TextEditingController(text: _c?.zone ?? 'Paris');
  late VehicleType _vehicle = _c?.vehicle ?? VehicleType.scooter;
  late CourierStatus _status = _c?.status ?? CourierStatus.offline;

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _email, _plate, _zone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final now = DateTime.now();
    var base = _c;
    if (base == null) {
      // Nouveau livreur : son compte utilisateur d'abord.
      final users = ref.read(userRepositoryProvider);
      if (await users.findByEmail(_email.text.trim()) != null) {
        throw const ApiException('Un compte existe déjà avec cet e-mail.');
      }
      final user = await users.create(
        User(
          id: '',
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          role: UserRole.courier,
          createdAt: now,
        ),
      );
      ref.invalidate(usersControllerProvider);
      base = Courier(
        id: '',
        userId: user.id,
        firstName: '',
        lastName: '',
        phone: '',
        documents: [
          for (final type in DocumentType.values)
            CourierDocument(type: type, uploadedAt: now),
        ],
        joinedAt: now,
      );
    }
    final plate = _plate.text.trim();
    await ref
        .read(couriersControllerProvider.notifier)
        .save(
          base.copyWith(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            phone: _phone.text.trim(),
            vehicle: _vehicle,
            plateNumber: _vehicle == VehicleType.bike || plate.isEmpty
                ? null
                : plate.toUpperCase(),
            zone: _zone.text.trim(),
            status: _status,
          ),
          isNew: _c == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _c == null;
    return AppForm(
      title: isNew ? 'Nouveau livreur' : 'Modifier le livreur',
      subtitle: isNew
          ? 'Ses justificatifs seront à vérifier.'
          : _c.fullName,
      icon: Icons.delivery_dining_rounded,
      successMessage: isNew ? 'Livreur ajouté' : 'Livreur mis à jour',
      onSubmit: _save,
      children: [
        const AppFormSection(title: 'Identité'),
        AppFormRow(
          children: [
            AppTextField(
              controller: _first,
              label: 'Prénom',
              validator: Validators.name,
            ),
            AppTextField(
              controller: _last,
              label: 'Nom',
              validator: Validators.name,
            ),
          ],
        ),
        AppTextField(
          controller: _phone,
          label: 'Téléphone',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: Validators.phone,
        ),
        if (isNew)
          AppTextField(
            controller: _email,
            label: 'E-mail (identifiant de connexion)',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
        const AppFormSection(title: 'Activité'),
        AppFormRow(
          children: [
            AppDropdownField<VehicleType>(
              label: 'Véhicule',
              value: _vehicle,
              items: VehicleType.values,
              itemLabel: (v) => v.label,
              onChanged: (v) => setState(() => _vehicle = v ?? _vehicle),
            ),
            AppTextField(
              controller: _plate,
              label: 'Immatriculation',
              hint: _vehicle == VehicleType.bike ? 'Aucune' : 'AB-123-CD',
              validator: (v) =>
                  _vehicle != VehicleType.bike && (v ?? '').trim().isEmpty
                  ? 'Immatriculation obligatoire'
                  : null,
            ),
          ],
        ),
        AppTextField(
          controller: _zone,
          label: 'Zone de livraison',
          prefixIcon: Icons.map_outlined,
          validator: (v) => Validators.required(v, field: 'La zone'),
        ),
        AppDropdownField<CourierStatus>(
          label: 'Statut',
          value: _status,
          items: CourierStatus.values,
          itemLabel: (s) => s.label,
          onChanged: (s) => setState(() => _status = s ?? _status),
        ),
      ],
    );
  }
}
