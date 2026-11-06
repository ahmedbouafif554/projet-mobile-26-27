import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/auth/biometric_login.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/models/user.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/theme/theme_mode_provider.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../providers/settings_providers.dart';
import '../widgets/profile_widgets.dart';
import 'profile_page.dart';

/// Paramètres : thème, langue, notifications, à propos et déconnexion.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final pushEnabled = ref.watch(pushEnabledProvider);
    final user = ref.watch(authServiceProvider).user;

    final t = language.tr;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AccountBackButton()),
        title: Text(t('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children:
            [
                  _SectionTitle(t('appearance')),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t('theme'), style: context.text.titleSmall),
                        const SizedBox(height: AppSizes.sm + 4),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(t('light')),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(t('dark')),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text(t('auto')),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (s) =>
                              ref.read(themeModeProvider.notifier).set(s.first),
                        ),
                      ],
                    ),
                  ),
                  _SectionTitle(t('language')),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final l in AppLanguage.values)
                          RadioListTile<AppLanguage>(
                            value: l,
                            groupValue: language,
                            activeColor: AppColors.primary,
                            title: Text('${l.flag}  ${l.label}'),
                            onChanged: (value) {
                              if (value == null) return;
                              ref.read(languageProvider.notifier).set(value);
                            },
                          ),
                      ],
                    ),
                  ),
                  if (user?.role == UserRole.client) ...[
                    _SectionTitle(t('security')),
                    const _BiometricSwitch(),
                  ],
                  _SectionTitle(t('notifications')),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile(
                      value: pushEnabled,
                      onChanged: ref.read(pushEnabledProvider.notifier).set,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: Text(t('push')),
                      subtitle: Text(t('pushSub')),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  ProfileMenuSection(
                    title: t('about'),
                    children: [
                      ProfileMenuTile(
                        icon: Icons.info_outline_rounded,
                        title: t('version'),
                        trailing: const Text('1.0.0'),
                      ),
                      ProfileMenuTile(
                        icon: Icons.description_outlined,
                        color: AppColors.info,
                        title: t('terms'),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'SuperFaster',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.lg),
                  OutlinedButton.icon(
                    onPressed: () => ProfilePage.confirmLogout(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(t('logout')),
                  ),
                  const SizedBox(height: AppSizes.lg),
                ]
                .animate(interval: 40.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0),
      ),
    );
  }
}

class _BiometricSwitch extends ConsumerWidget {
  const _BiometricSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final enabled = ref.watch(clientBiometricEnabledProvider);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        value: enabled.asData?.value ?? false,
        onChanged: enabled.isLoading
            ? null
            : (value) => _set(context, ref, value),
        secondary: const Icon(Icons.face_rounded),
        title: Text(language.tr('face')),
        subtitle: Text(language.tr('faceSub')),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, bool value) async {
    final gate = ref.read(biometricLoginProvider);
    if (value) {
      if (!await gate.isAvailable) {
        if (context.mounted) {
          AppSnackbar.error(
            context,
            ref.read(languageProvider).tr('noFace'),
          );
        }
        return;
      }
      if (!await gate.authenticate()) {
        if (context.mounted) {
          AppSnackbar.error(
            context,
            ref.read(languageProvider).tr('faceCancelled'),
          );
        }
        return;
      }
      final user = ref.read(authServiceProvider).user;
      final token = ref.read(authTokenProvider);
      if (user == null || token == null || token.isEmpty) return;
      await gate.enable(user: user, token: token);
    } else {
      await gate.disable();
    }
    ref.invalidate(clientBiometricEnabledProvider);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, AppSizes.md, 0, AppSizes.sm),
      child: Text(
        title.toUpperCase(),
        style: context.text.labelMedium?.copyWith(
          color: context.palette.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
