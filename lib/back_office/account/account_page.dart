import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_form_fields.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../shared/repositories/repository_providers.dart';
import '../../shared/widgets/status_chips.dart';
import '../modules/users/users_controller.dart';
import '../shared/bo_widgets.dart';
import '../shell/bo_page.dart';

/// Mon compte (admin et restaurateur) : profil, mot de passe, préférences
/// d'affichage et déconnexion.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  late final _user = ref.read(authServiceProvider).user!;
  late final _first = TextEditingController(text: _user.firstName);
  late final _last = TextEditingController(text: _user.lastName);
  late final _email = TextEditingController(text: _user.email);
  late final _phone = TextEditingController(text: _user.phone);
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final current = ref.read(authServiceProvider).user!;
      final updated = await ref
          .read(userRepositoryProvider)
          .update(
            current.copyWith(
              firstName: _first.text.trim(),
              lastName: _last.text.trim(),
              email: _email.text.trim(),
              phone: _phone.text.trim(),
            ),
          );
      ref.read(authServiceProvider.notifier).updateUser(updated);
      ref.invalidate(usersControllerProvider);
      if (mounted) AppSnackbar.success(context, 'Profil mis à jour');
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    // Mock : aucun mot de passe n'est stocké, on simule l'appel.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    for (final c in [_current, _new, _confirm]) {
      c.clear();
    }
    setState(() => _savingPassword = false);
    AppSnackbar.success(context, 'Mot de passe modifié');
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous devrez saisir à nouveau vos identifiants.',
      confirmLabel: 'Déconnexion',
      icon: Icons.logout_rounded,
    );
    if (confirmed) ref.read(authServiceProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).user;
    if (user == null) return const SizedBox.shrink();
    final mode = ref.watch(themeModeProvider);

    final profile = SectionCard(
      title: 'Profil',
      icon: Icons.person_outline_rounded,
      child: Form(
        key: _profileKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(name: user.fullName, imageUrl: user.avatarUrl, size: 64),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: context.text.titleLarge),
                      const SizedBox(height: 4),
                      userRoleChip(user.role),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
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
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _email,
              label: 'Adresse e-mail',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _phone,
              label: 'Téléphone',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSizes.lg),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _savingProfile ? null : _saveProfile,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: _savingProfile
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );

    final password = SectionCard(
      title: 'Mot de passe',
      icon: Icons.lock_outline_rounded,
      child: Form(
        key: _passwordKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _current,
              label: 'Mot de passe actuel',
              isPassword: true,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _new,
              label: 'Nouveau mot de passe',
              isPassword: true,
              validator: Validators.password,
            ),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _confirm,
              label: 'Confirmer le mot de passe',
              isPassword: true,
              validator: (v) => v != _new.text
                  ? 'Les mots de passe ne correspondent pas'
                  : null,
            ),
            const SizedBox(height: AppSizes.lg),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _savingPassword ? null : _savePassword,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.key_rounded),
                label: const Text('Modifier le mot de passe'),
              ),
            ),
          ],
        ),
      ),
    );

    final preferences = SectionCard(
      title: 'Préférences',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thème', style: context.text.labelLarge),
          const SizedBox(height: AppSizes.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Clair'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Sombre'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest_rounded),
                label: Text('Auto'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: AppSizes.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.md),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    return BoPage(
      title: 'Mon compte',
      subtitle: 'Vos informations personnelles et vos préférences.',
      children: [
        SplitRow(
          left: profile,
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [password, boGap, preferences],
          ),
        ),
      ],
    );
  }
}
