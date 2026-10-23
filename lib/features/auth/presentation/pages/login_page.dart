import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/auth_mock_data.dart';
import '../widgets/auth_header.dart';
import '../widgets/social_buttons.dart';

/// Écran de connexion (simulée : aucun appel réseau).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  // Pré-rempli pour faciliter les tests de l'équipe.
  final _email = TextEditingController(text: AuthMockData.demoEmail);
  final _password = TextEditingController(text: AuthMockData.demoPassword);
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  Future<void> _socialLogin(SocialProvider provider) async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.go(AppRoutes.home);
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
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    [
                          const AuthHeader(
                            title: 'Bon retour 👋',
                            subtitle:
                                'Connectez-vous pour commander vos plats préférés.',
                          ),
                          const SizedBox(height: AppSizes.xl),
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
                                  context.push(AppRoutes.forgotPassword),
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          PrimaryButton(
                            label: 'Se connecter',
                            isLoading: _loading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: AppSizes.xl),
                          const OrDivider(),
                          const SizedBox(height: AppSizes.lg),
                          SocialButtons(onTap: _socialLogin),
                          const SizedBox(height: AppSizes.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Pas encore de compte ?',
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.push(AppRoutes.register),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                ),
                                child: const Text("S'inscrire"),
                              ),
                            ],
                          ),
                        ]
                        .animate(interval: 50.ms)
                        .fadeIn(duration: 450.ms)
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
