import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/shake_widget.dart';
import '../../../../router/front_routes.dart';
import '../widgets/auth_header.dart';
import '../widgets/otp_input.dart';

/// Vérification du numéro après l'inscription (code de démo : 1234).
/// Un code correct ouvre la session : le routeur affiche l'accueil.
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, required this.phone, this.userId});

  final String phone;

  /// Compte créé à l'inscription (null si la page est ouverte directement).
  final String? userId;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  static const _resendDelay = 30;

  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendDelay;
  int _errorCount = 0;
  bool _hasError = false;
  bool _loading = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _code.addListener(() {
      if (_hasError) setState(() => _hasError = false);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length < 4 || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (_code.text != AuthService.demoOtpCode) {
      setState(() {
        _loading = false;
        _hasError = true;
        _errorCount++;
      });
      return;
    }

    // Animation de succès, puis ouverture de la session.
    setState(() {
      _loading = false;
      _verified = true;
    });
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final userId = widget.userId;
    if (userId == null) {
      context.go(FrontRoutes.login);
      return;
    }
    try {
      await ref
          .read(authServiceProvider.notifier)
          .verifyOtp(userId: userId, code: _code.text);
    } catch (error) {
      if (mounted) {
        AppSnackbar.error(context, error);
        setState(() => _verified = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.phone.isEmpty ? 'votre numéro' : widget.phone;
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppDurations.slow,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: _verified ? const _VerifiedView() : _form(context, phone),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, String phone) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: 'Vérification',
            subtitle: 'Saisissez le code à 4 chiffres envoyé au $phone.',
            showBack: true,
          ),
          const SizedBox(height: AppSizes.xl),
          ShakeWidget(
            trigger: _errorCount == 0 ? null : _errorCount,
            child: OtpInput(
              controller: _code,
              hasError: _hasError,
              onCompleted: (_) => _verify(),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            child: Text(
              _hasError
                  ? 'Code incorrect, veuillez réessayer.'
                  : 'Démo : saisissez ${AuthService.demoOtpCode}',
              key: ValueKey(_hasError),
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: _hasError
                    ? AppColors.error
                    : context.palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          PrimaryButton(
            label: 'Vérifier',
            isLoading: _loading,
            onPressed: _verify,
          ),
          const SizedBox(height: AppSizes.lg),
          Center(
            child: _secondsLeft > 0
                ? Text(
                    'Renvoyer le code dans 00:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  )
                : TextButton.icon(
                    onPressed: () {
                      _startTimer();
                      AppSnackbar.success(
                        context,
                        'Un nouveau code a été envoyé',
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Renvoyer le code'),
                  ),
          ),
        ].animate(interval: 60.ms).fadeIn(duration: 400.ms).slideY(begin: 0.12, end: 0),
      ),
    );
  }
}

/// Vue affichée après une vérification réussie.
class _VerifiedView extends StatelessWidget {
  const _VerifiedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('verified'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 60,
            ),
          ).animate().scaleXY(
            begin: 0,
            end: 1,
            duration: 700.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'Numéro vérifié !',
            style: context.text.headlineSmall,
          ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.3, end: 0),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Bienvenue sur SuperFaster 🎉',
            style: context.text.bodyLarge?.copyWith(
              color: context.palette.textSecondary,
            ),
          ).animate(delay: 400.ms).fadeIn(),
        ],
      ),
    );
  }
}
