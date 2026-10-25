import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../shared/mock/mock_users.dart';
import 'restaurant_signup_form.dart';

/// Connexion à l'Espace Pro (admin et restaurateurs). Les comptes client et
/// livreur sont refusés : ils utilisent l'application mobile.
class BackLoginPage extends ConsumerStatefulWidget {
  const BackLoginPage({super.key});

  @override
  ConsumerState<BackLoginPage> createState() => _BackLoginPageState();
}

class _BackLoginPageState extends ConsumerState<BackLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: DemoAccounts.admin);
  final _password = TextEditingController(text: DemoAccounts.password);
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider.notifier)
          .login(
            email: _email.text.trim(),
            password: _password.text,
            space: AppSpace.backOffice,
          );
      // Succès : le routeur ouvre le tableau de bord.
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Remplit le formulaire avec un compte de démonstration et se connecte.
  void _demo(String email) {
    _email.text = email;
    _password.text = DemoAccounts.password;
    _login();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final form = _LoginForm(
      formKey: _formKey,
      email: _email,
      password: _password,
      submitted: _submitted,
      loading: _loading,
      onLogin: _login,
      onDemo: _demo,
    );

    return Scaffold(
      body: Row(
        children: [
          if (wide) const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 4,
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: form,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      tooltip: 'Thème clair / sombre',
                      onPressed: ref.read(themeModeProvider.notifier).toggle,
                      icon: Icon(
                        context.isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.email,
    required this.password,
    required this.submitted,
    required this.loading,
    required this.onLogin,
    required this.onDemo,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool submitted;
  final bool loading;
  final VoidCallback onLogin;
  final ValueChanged<String> onDemo;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(
      color: context.palette.textSecondary,
    );
    return Form(
      key: formKey,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(size: 52, showName: true),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    Text(
                      "Connexion à l'Espace Pro",
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      'Administration de la plateforme et gestion des restaurants partenaires.',
                      style: muted,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    AppTextField(
                      controller: email,
                      label: 'Adresse e-mail professionnelle',
                      hint: 'vous@restaurant.fr',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: password,
                      label: 'Mot de passe',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: Validators.password,
                      onSubmitted: (_) => onLogin(),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    PrimaryButton(
                      label: 'Se connecter',
                      icon: Icons.login_rounded,
                      isLoading: loading,
                      onPressed: onLogin,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Comptes de démonstration',
                            style: context.text.bodySmall?.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        Expanded(
                          child: _DemoButton(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Admin démo',
                            onTap: loading
                                ? null
                                : () => onDemo(DemoAccounts.admin),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm + 4),
                        Expanded(
                          child: _DemoButton(
                            icon: Icons.storefront_rounded,
                            label: 'Restaurant démo',
                            onTap: loading
                                ? null
                                : () => onDemo(DemoAccounts.restaurant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Vous êtes restaurateur ?', style: muted),
                        TextButton(
                          onPressed: () => showRestaurantSignup(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('Inscrire mon restaurant'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Clients et livreurs : utilisez l'application mobile SuperFaster.",
                              style: context.text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  .animate(interval: 40.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(icon, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }
}

/// Panneau de marque (grand écran) : dégradé, accroche et chiffres clés.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    const white70 = TextStyle(color: Colors.white70, height: 1.5);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF7A45), AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Cercles décoratifs animés.
          Positioned(
            top: -80,
            right: -60,
            child: _Bubble(size: 280, delay: 0.ms),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _Bubble(size: 360, delay: 400.ms),
          ),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SuperFaster Pro',
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Pilotez votre activité\nen temps réel.',
                  style: context.text.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05),
                const SizedBox(height: AppSizes.md),
                const Text(
                  'Commandes, menus, livreurs et avis clients réunis dans un '
                  'seul tableau de bord.',
                  style: white70,
                ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
                const SizedBox(height: AppSizes.xl),
                Wrap(
                  spacing: AppSizes.md,
                  runSpacing: AppSizes.md,
                  children: [
                    for (final (i, (icon, value, label)) in const [
                      (Icons.storefront_rounded, '120+', 'restaurants'),
                      (Icons.delivery_dining_rounded, '25 min', 'livraison moy.'),
                      (Icons.star_rounded, '4,8/5', 'satisfaction'),
                    ].indexed)
                      _BrandStat(icon: icon, value: value, label: label)
                          .animate(delay: (300 + 120 * i).ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.3, end: 0),
                  ],
                ),
                const Spacer(),
                const Text(
                  '© 2026 SuperFaster — Espace réservé aux partenaires.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.delay});

  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true), delay: delay)
        .scaleXY(begin: 0.92, end: 1.05, duration: 4.seconds, curve: Curves.easeInOut);
  }
}

class _BrandStat extends StatelessWidget {
  const _BrandStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            style: context.text.titleLarge?.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
