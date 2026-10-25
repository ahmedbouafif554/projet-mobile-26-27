import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AccountBackButton()),
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children:
            [
                  _SectionTitle('Apparence'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Thème', style: context.text.titleSmall),
                        const SizedBox(height: AppSizes.sm + 4),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Clair'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Sombre'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Auto'),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (s) =>
                              ref.read(themeModeProvider.notifier).set(s.first),
                        ),
                      ],
                    ),
                  ),
                  _SectionTitle('Langue'),
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
                              if (value != AppLanguage.fr) {
                                AppSnackbar.info(
                                  context,
                                  'Traduction à venir : '
                                  "l'interface reste en français.",
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  _SectionTitle('Notifications'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile(
                      value: pushEnabled,
                      onChanged: ref.read(pushEnabledProvider.notifier).set,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('Notifications push'),
                      subtitle: const Text(
                        'Suivi de commande, messages, offres',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  ProfileMenuSection(
                    title: 'À propos',
                    children: [
                      const ProfileMenuTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Version',
                        trailing: Text('1.0.0'),
                      ),
                      ProfileMenuTile(
                        icon: Icons.description_outlined,
                        color: AppColors.info,
                        title: "Conditions d'utilisation",
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
                    label: const Text('Déconnexion'),
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
