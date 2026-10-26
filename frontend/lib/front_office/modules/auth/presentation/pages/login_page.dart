import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/auth/permissions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/mock/mock_users.dart';
import '../../../../../shared/models/user.dart';
import '../../../../router/front_routes.dart';
import '../widgets/auth_header.dart';
import '../widgets/role_toggle.dart';
import '../widgets/social_buttons.dart';

/// Connexion unique : client, livreur ou admin, e-mail et mot de passe.
/// Une fois connecté, l'accueil du rôle s'ouvre dans la même fenêtre.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  // Pré-remplis avec les comptes de démo pour tester rapidement.
  final _email = TextEditingController(text: DemoAccounts.client);
  final _password = TextEditingController(text: DemoAccounts.password);
  UserRole _role = UserRole.client;
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Changer de rôle remplace l'e-mail de démo par celui du rôle choisi.
  void _changeRole(UserRole role) {
    const demo = {
      UserRole.client: DemoAccounts.client,
      UserRole.courier: DemoAccounts.courier,
      UserRole.admin: DemoAccounts.admin,
    };
    setState(() {
      if (demo.containsValue(_email.text.trim())) _email.text = demo[role]!;
      _role = role;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      // Succès : le routeur redirige vers l'accueil du rôle.
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    await _run(
      () => ref
          .read(authServiceProvider.notifier)
          .login(
            email: _email.text.trim(),
            password: _password.text,
            space: Permissions.spaceOf(_role),
            role: _role,
          ),
    );
  }

  /// Connexion sociale simulée : compte de démo du rôle choisi.
  Future<void> _socialLogin(SocialProvider provider) =>
      _run(() => ref.read(authServiceProvider.notifier).loginAs(_role));

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_role) {
      UserRole.courier => 'Connectez-vous pour recevoir des courses.',
      UserRole.admin => 'Connectez-vous pour administrer la plateforme.',
      _ => 'Connectez-vous pour commander vos plats préférés.',
    };
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    [
                          AuthHeader(
                            title: 'Bon retour 👋',
                            subtitle: subtitle,
                          ),
                          const SizedBox(height: AppSizes.lg),
                          Text('Je suis', style: context.text.labelLarge),
                          const SizedBox(height: AppSizes.sm),
                          RoleToggle(
                            value: _role,
                            roles: const [
                              UserRole.client,
                              UserRole.courier,
                              UserRole.admin,
                            ],
                            onChanged: _changeRole,
                          ),
                          const SizedBox(height: AppSizes.lg),
                          AppTextField(
                            controller: _email,
                            label: 'Adresse e-mail',
                            hint: 'vous@exemple.fr',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _password,
                            label: 'Mot de passe',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: Validators.password,
                            onSubmitted: (_) => _submit(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(FrontRoutes.forgotPassword),
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          PrimaryButton(
                            label: 'Se connecter',
                            isLoading: _loading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: AppSizes.lg),
                          const OrDivider(),
                          const SizedBox(height: AppSizes.lg),
                          SocialButtons(onTap: _socialLogin),
                          const SizedBox(height: AppSizes.lg),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Pas encore de compte ?',
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.push(FrontRoutes.register),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                ),
                                child: const Text("S'inscrire"),
                              ),
                            ],
                          ),
                        ]
                        .animate(interval: 45.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(
                          begin: 0.12,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
