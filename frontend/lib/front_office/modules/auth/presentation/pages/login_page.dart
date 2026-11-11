import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/auth/biometric_login.dart';
import '../../../../../core/auth/permissions.dart';
import '../../../../../core/config/app_config.dart';
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
  final _email = TextEditingController(
    text: AppConfig.demoMode ? DemoAccounts.client : '',
  );
  final _password = TextEditingController(
    text: AppConfig.demoMode ? DemoAccounts.password : '',
  );
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

  /// Connexion Google : vérifiée par le serveur (compte de démo du rôle
  /// choisi en mode démonstration).
  Future<void> _socialLogin(SocialProvider provider) => _run(
    () => ref
        .read(authServiceProvider.notifier)
        .loginWithGoogle(role: _role, space: Permissions.spaceOf(_role)),
  );

  /// Déverrouille la session client déjà enregistrée sur cet appareil.
  Future<void> _biometricLogin() async {
    final gate = ref.read(biometricLoginProvider);
    final confirmed = await gate.authenticate();
    if (!confirmed) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Reconnaissance faciale annulée ou indisponible.',
        );
      }
      return;
    }
    final saved = await gate.readSession();
    if (saved == null) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Aucune session client enregistrée. Connectez-vous avec votre mot de passe.',
        );
      }
      return;
    }
    await _run(() async {
      ref
          .read(authServiceProvider.notifier)
          .restoreBiometricSession(user: saved.user, token: saved.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final biometricEnabled = ref.watch(clientBiometricEnabledProvider);
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
                          if (_role == UserRole.client &&
                              biometricEnabled.asData?.value == true) ...[
                            const SizedBox(height: AppSizes.sm),
                            OutlinedButton.icon(
                              onPressed: _loading ? null : _biometricLogin,
                              icon: const Icon(Icons.face_rounded),
                              label: const Text(
                                'Connexion par reconnaissance faciale',
                              ),
                            ),
                          ],
                          if (AppConfig.googleSignInEnabled) ...[
                            const SizedBox(height: AppSizes.lg),
                            const OrDivider(),
                            const SizedBox(height: AppSizes.lg),
                            SocialButtons(onTap: _socialLogin),
                          ],
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
