import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../router/front_routes.dart';
import '../widgets/auth_header.dart';

/// Mot de passe oublié : envoi (simulé) d'un lien de réinitialisation.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // Par sécurité, on ne dit pas si l'e-mail existe : même message pour tous.
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _loading = false;
        _sent = true;
      });
    }
  }

  void _backToLogin() =>
      context.canPop() ? context.pop() : context.go(FrontRoutes.login);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppDurations.slow,
          child: _sent ? _sentView(context) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              [
                    const AuthHeader(
                      title: 'Mot de passe oublié',
                      subtitle:
                          'Indiquez votre e-mail : nous vous enverrons un '
                          'lien pour choisir un nouveau mot de passe.',
                      showBack: true,
                    ),
                    const SizedBox(height: AppSizes.xl),
                    AppTextField(
                      controller: _email,
                      label: 'Adresse e-mail',
                      hint: 'vous@exemple.fr',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      onSubmitted: (_) => _send(),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    PrimaryButton(
                      label: 'Envoyer le lien',
                      icon: Icons.send_rounded,
                      isLoading: _loading,
                      onPressed: _send,
                    ),
                  ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.12, end: 0),
        ),
      ),
    );
  }

  Widget _sentView(BuildContext context) {
    return Center(
      key: const ValueKey('sent'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              AppAssets.lottieSuccess,
              width: 180,
              height: 180,
              repeat: false,
            ),
            Text('E-mail envoyé !', style: context.text.headlineSmall),
            const SizedBox(height: AppSizes.sm),
            Text(
              'Si un compte existe pour ${_email.text.trim()}, vous recevrez '
              'un lien de réinitialisation dans quelques minutes.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            PrimaryButton(
              label: 'Retour à la connexion',
              onPressed: _backToLogin,
            ),
          ].animate(interval: 80.ms).fadeIn(duration: 400.ms),
        ),
      ),
    );
  }
}
