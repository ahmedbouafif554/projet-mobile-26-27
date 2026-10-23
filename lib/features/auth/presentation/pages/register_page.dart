import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/shake_widget.dart';
import '../widgets/auth_header.dart';

/// Écran d'inscription. Après validation, on passe à la vérification OTP.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _acceptedTerms = false;
  bool _submitted = false;
  bool _loading = false;
  int _termsShake = 0;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!_acceptedTerms) {
      setState(() => _termsShake++);
      AppSnackbar.error(
        context,
        "Veuillez accepter les conditions d'utilisation",
      );
    }
    if (!valid || !_acceptedTerms) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _loading = false);
    context.push(AppRoutes.otpFor(_phone.text.trim()));
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
                              'Rejoignez SuperFaster et faites-vous livrer en un éclair ⚡',
                          showBack: true,
                        ),
                        const SizedBox(height: AppSizes.xl),
                        AppTextField(
                          controller: _name,
                          label: 'Nom complet',
                          hint: 'Alex Martin',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          validator: Validators.name,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _email,
                          label: 'Adresse e-mail',
                          hint: 'vous@exemple.fr',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _phone,
                          label: 'Téléphone',
                          hint: '06 12 34 56 78',
                          prefixIcon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _password,
                          label: 'Mot de passe',
                          hint: '6 caractères minimum',
                          prefixIcon: Icons.lock_outline_rounded,
                          isPassword: true,
                          validator: Validators.password,
                        ),
                        const SizedBox(height: AppSizes.md),
                        ShakeWidget(
                          trigger: _termsShake == 0 ? null : _termsShake,
                          child: _TermsCheckbox(
                            value: _acceptedTerms,
                            onChanged: (v) =>
                                setState(() => _acceptedTerms = v),
                          ),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        PrimaryButton(
                          label: 'Créer mon compte',
                          isLoading: _loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSizes.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                                  : context.go(AppRoutes.login),
                              child: const Text('Se connecter'),
                            ),
                          ],
                        ),
                      ]
                      .animate(interval: 40.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        ),
      ),
    );
  }
}

/// Case à cocher des CGU avec coche animée.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: value
                      ? AppColors.primary
                      : context.palette.textSecondary,
                  width: 1.6,
                ),
              ),
              child: AnimatedScale(
                scale: value ? 1 : 0,
                duration: AppDurations.fast,
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: "J'accepte les ",
                  style: context.text.bodyMedium,
                  children: const [
                    TextSpan(
                      text: "conditions d'utilisation",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' et la politique de confidentialité.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
