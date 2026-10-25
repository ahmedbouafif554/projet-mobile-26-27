import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/models/models.dart';
import '../catalog/catalog_controllers.dart';
import 'users_controller.dart';

/// Création ([user] null) ou modification d'un utilisateur.
Future<bool> openUserForm(BuildContext context, {User? user}) =>
    showAppForm(context, UserForm(user: user));

class UserForm extends ConsumerStatefulWidget {
  const UserForm({super.key, this.user});

  final User? user;

  @override
  ConsumerState<UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<UserForm> {
  late final _first = TextEditingController(text: widget.user?.firstName);
  late final _last = TextEditingController(text: widget.user?.lastName);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  late final _points = TextEditingController(
    text: '${widget.user?.loyaltyPoints ?? 0}',
  );
  late UserRole _role = widget.user?.role ?? UserRole.client;
  late UserStatus _status = widget.user?.status ?? UserStatus.active;
  late String? _restaurantId = widget.user?.restaurantId;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _points]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final isNew = widget.user == null;
    final base =
        widget.user ??
        User(
          id: '',
          firstName: '',
          lastName: '',
          email: '',
          phone: '',
          role: _role,
          createdAt: DateTime.now(),
        );
    await ref
        .read(usersControllerProvider.notifier)
        .save(
          base.copyWith(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            status: _status,
            restaurantId: _role == UserRole.restaurant ? _restaurantId : null,
            loyaltyPoints: int.tryParse(_points.text.trim()) ?? 0,
          ),
          isNew: isNew,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.user == null;
    final restaurants =
        ref.watch(restaurantsControllerProvider).value ?? const [];
    return AppForm(
      title: isNew ? 'Nouvel utilisateur' : "Modifier l'utilisateur",
      subtitle: isNew
          ? 'Un e-mail d’activation sera envoyé au nouvel utilisateur.'
          : widget.user!.email,
      icon: isNew
          ? Icons.person_add_alt_1_rounded
          : Icons.manage_accounts_rounded,
      successMessage: isNew ? 'Utilisateur créé' : 'Modifications enregistrées',
      onSubmit: _save,
      children: [
        const AppFormSection(title: 'Identité'),
        AppFormRow(
          children: [
            AppTextField(
              controller: _first,
              label: 'Prénom',
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
            ),
            AppTextField(
              controller: _last,
              label: 'Nom',
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
            ),
          ],
        ),
        const AppFormSection(title: 'Contact'),
        AppTextField(
          controller: _email,
          label: 'Adresse e-mail',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        AppTextField(
          controller: _phone,
          label: 'Téléphone',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: Validators.phone,
        ),
        const AppFormSection(
          title: 'Accès',
          subtitle: 'Le rôle détermine l’application et les écrans autorisés.',
        ),
        AppFormRow(
          children: [
            AppDropdownField<UserRole>(
              label: 'Rôle',
              value: _role,
              items: UserRole.values,
              itemLabel: (r) => r.label,
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
            AppDropdownField<UserStatus>(
              label: 'Statut',
              value: _status,
              items: UserStatus.values,
              itemLabel: (s) => s.label,
              onChanged: (s) => setState(() => _status = s ?? _status),
            ),
          ],
        ),
        if (_role == UserRole.restaurant)
          AppDropdownField<String>(
            label: 'Restaurant géré',
            prefixIcon: Icons.storefront_outlined,
            value: restaurants.any((r) => r.id == _restaurantId)
                ? _restaurantId
                : null,
            items: [for (final r in restaurants) r.id],
            itemLabel: (id) => restaurants.firstWhere((r) => r.id == id).name,
            onChanged: (id) => setState(() => _restaurantId = id),
            validator: (id) =>
                id == null ? 'Choisissez le restaurant géré' : null,
          ),
        if (_role == UserRole.client)
          AppTextField(
            controller: _points,
            label: 'Points de fidélité',
            prefixIcon: Icons.loyalty_outlined,
            keyboardType: TextInputType.number,
            validator: (v) => int.tryParse(v?.trim() ?? '') == null
                ? 'Nombre entier attendu'
                : null,
          ),
      ],
    );
  }
}

/// Choix d'un nouveau rôle (boîte de dialogue).
Future<UserRole?> pickRole(BuildContext context, User user) =>
    showDialog<UserRole>(
      context: context,
      builder: (context) => _RoleDialog(user: user),
    );

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.user});

  final User user;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late UserRole _role = widget.user.role;

  static const _descriptions = {
    UserRole.client: 'Commande dans l’application mobile.',
    UserRole.courier: 'Livre les commandes (application mobile).',
    UserRole.restaurant: 'Gère son restaurant dans l’Espace Pro.',
    UserRole.admin: 'Accès complet à l’Espace Pro.',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rôle de ${widget.user.firstName}'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final role in UserRole.values)
              RadioListTile<UserRole>(
                value: role,
                groupValue: _role,
                onChanged: (r) => setState(() => _role = r ?? _role),
                title: Text(role.label),
                subtitle: Text(_descriptions[role]!),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _role == widget.user.role
              ? null
              : () => Navigator.pop(context, _role),
          child: const Text('Changer le rôle'),
        ),
      ],
    );
  }
}
