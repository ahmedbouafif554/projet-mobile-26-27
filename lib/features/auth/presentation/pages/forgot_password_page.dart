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
import '../widgets/auth_header.dart';

/// Mot de passe oublié : saisie de l'e-mail puis confirmation d'envoi.
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
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

  void _backToLogin() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: AnimatedSwitcher(
            duration: AppDurations.slow,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.15, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _sent ? _buildSent(context) : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            title: 'Mot de passe oublié ?',
            subtitle:
                'Pas de panique ! Indiquez votre e-mail et nous vous enverrons un lien de réinitialisation.',
            showBack: true,
          ),
          const SizedBox(height: AppSizes.xl),
          AppTextField(
            controller: _email,
            label: 'Adresse e-mail',
            hint: 'vous@exemple.fr',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
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
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSizes.xxl),
        Center(
          child:
              Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 56,
                      color: AppColors.primary,
                    ),
                  )
                  .animate()
                  .scaleXY(
                    begin: 0.3,
                    end: 1,
                    duration: 700.ms,
                    curve: Curves.elasticOut,
                  )
                  .then()
                  .shake(hz: 3, rotation: 0.05, duration: 500.ms),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          'E-mail envoyé !',
          style: context.text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          'Consultez votre boîte de réception (${_email.text.trim()}) et suivez le lien pour choisir un nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.xl),
        PrimaryButton(label: 'Retour à la connexion', onPressed: _backToLogin),
        const SizedBox(height: AppSizes.sm),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text("Je n'ai rien reçu"),
        ),
      ],
    );
  }
}
