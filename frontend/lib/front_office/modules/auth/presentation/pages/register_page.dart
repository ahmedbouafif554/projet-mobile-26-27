import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_form_fields.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/user.dart';
import '../../../../router/front_routes.dart';
import '../widgets/auth_header.dart';
import '../widgets/role_toggle.dart';

/// Inscription d'un client ou d'un livreur partenaire, puis vérification
/// du numéro de téléphone (OTP).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.client;
  bool _accepted = false;
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = await ref
          .read(authServiceProvider.notifier)
          .register(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            role: _role,
          );
      if (!mounted) return;
      context.push(
        FrontRoutes.otpFor(phone: _phone.text.trim(), userId: user.id),
      );
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  [
                        const AuthHeader(
                          title: 'Créer un compte',
                          subtitle:
                              'Rejoignez SuperFaster en moins d\'une minute.',
                          showBack: true,
                        ),
                        const SizedBox(height: AppSizes.lg),
                        Text('Je veux', style: context.text.labelLarge),
                        const SizedBox(height: AppSizes.sm),
                        RoleToggle(
                          value: _role,
                          courierLabel: 'Livrer',
                          onChanged: (r) => setState(() => _role = r),
                        ),
                        AnimatedSize(
                          duration: AppDurations.medium,
                          child: _role == UserRole.courier
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Vos justificatifs seront vérifiés par '
                                    'notre équipe avant votre première course.',
                                    style: context.text.bodySmall?.copyWith(
                                      color: context.palette.textSecondary,
                                    ),
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        AppFormRow(
                          children: [
                            AppTextField(
                              controller: _firstName,
                              label: 'Prénom',
                              textCapitalization: TextCapitalization.words,
                              validator: Validators.name,
                            ),
                            AppTextField(
                              controller: _lastName,
                              label: 'Nom',
                              textCapitalization: TextCapitalization.words,
                              validator: Validators.name,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _email,
                          label: 'Adresse e-mail',
                          hint: 'vous@exemple.fr',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _phone,
                          label: 'Téléphone',
                          hint: '06 12 34 56 78',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _password,
                          label: 'Mot de passe',
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _confirm,
                          label: 'Confirmer le mot de passe',
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: (v) => v != _password.text
                              ? 'Les mots de passe ne correspondent pas'
                              : null,
                        ),
                        const SizedBox(height: AppSizes.sm),
                        FormField<bool>(
                          initialValue: _accepted,
                          validator: (_) => _accepted
                              ? null
                              : 'Veuillez accepter les conditions',
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: _accepted,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: AppColors.primary,
                                onChanged: (v) {
                                  setState(() => _accepted = v ?? false);
                                  field.didChange(v);
                                },
                                title: Text(
                                  "J'accepte les conditions d'utilisation "
                                  'et la politique de confidentialité',
                                  style: context.text.bodySmall,
                                ),
                              ),
                              if (field.hasError)
                                Text(
                                  field.errorText!,
                                  style: context.text.bodySmall?.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        PrimaryButton(
                          label: 'Créer mon compte',
                          isLoading: _loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSizes.md),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Déjà inscrit ?',
                              style: context.text.bodyMedium?.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go(FrontRoutes.login),
                              child: const Text('Se connecter'),
                            ),
                          ],
                        ),
                      ]
                      .animate(interval: 35.ms)
                      .fadeIn(duration: 380.ms)
                      .slideY(begin: 0.1, end: 0),
            ),
          ),
        ),
      ),
    );
  }
}
