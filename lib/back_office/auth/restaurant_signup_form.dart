import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_form.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../core/widgets/app_text_field.dart';

/// Ouvre le formulaire de demande d'inscription d'un restaurant.
Future<void> showRestaurantSignup(BuildContext context) =>
    showAppFormDialog(context, const RestaurantSignupForm());

/// Demande d'inscription : le restaurant et le compte du restaurateur sont
/// créés « en attente » jusqu'à la validation par l'admin.
class RestaurantSignupForm extends ConsumerStatefulWidget {
  const RestaurantSignupForm({super.key});

  @override
  ConsumerState<RestaurantSignupForm> createState() =>
      _RestaurantSignupFormState();
}

class _RestaurantSignupFormState extends ConsumerState<RestaurantSignupForm> {
  final _name = TextEditingController();
  final _cuisine = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _name,
      _cuisine,
      _address,
      _phone,
      _first,
      _last,
      _email,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() => ref
      .read(authServiceProvider.notifier)
      .registerRestaurant(
        restaurantName: _name.text.trim(),
        cuisine: _cuisine.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );

  @override
  Widget build(BuildContext context) {
    return AppForm(
      title: 'Inscrire mon restaurant',
      subtitle: 'Votre demande sera étudiée sous 48 h.',
      icon: Icons.storefront_rounded,
      submitLabel: 'Envoyer la demande',
      successMessage:
          'Demande envoyée ! Vous recevrez un e-mail après validation.',
      onSubmit: _submit,
      children: [
        const AppFormSection(title: 'Restaurant'),
        AppTextField(
          controller: _name,
          label: 'Nom du restaurant',
          prefixIcon: Icons.storefront_outlined,
          validator: Validators.name,
        ),
        AppFormRow(
          children: [
            AppTextField(
              controller: _cuisine,
              label: 'Type de cuisine',
              hint: 'Pizza • Italien',
              validator: (v) => Validators.required(v, field: 'Le type'),
            ),
            AppTextField(
              controller: _phone,
              label: 'Téléphone',
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
          ],
        ),
        AppTextField(
          controller: _address,
          label: 'Adresse',
          prefixIcon: Icons.place_outlined,
          validator: (v) => Validators.required(v, field: "L'adresse"),
        ),
        const AppFormSection(title: 'Responsable'),
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
          controller: _email,
          label: 'E-mail professionnel',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        AppTextField(
          controller: _password,
          label: 'Mot de passe',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          validator: Validators.password,
        ),
      ],
    );
  }
}
