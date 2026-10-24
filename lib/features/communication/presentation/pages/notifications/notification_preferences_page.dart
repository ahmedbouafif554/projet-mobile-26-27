import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../models/app_notification.dart';
import '../../../models/notification_settings.dart';
import '../../controllers/notification_center_controller.dart';
import '../../widgets/notifications/notification_style.dart';

/// Réglages des notifications : activation par type, bannières in-app,
/// son et mode « Ne pas déranger ».
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final _center = NotificationCenterController.instance;

  @override
  void initState() {
    super.initState();
    _center.load();
  }

  Future<void> _update(NotificationSettings settings) async {
    final error = await _center.updateSettings(settings);
    if (error != null && mounted) AppSnackbar.error(context, error);
  }

  void _test() {
    final settings = _center.settings;
    _center.simulatePush();
    if (!settings.inAppBanner || settings.doNotDisturb) {
      AppSnackbar.show(
        context,
        'Bannières désactivées : la notification a été ajoutée à la liste.',
        icon: Icons.notifications_paused_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Réglages des notifications'),
      ),
      body: ListenableBuilder(
        listenable: _center,
        builder: (context, _) {
          final settings = _center.settings;
          final muted = settings.doNotDisturb;

          return ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              _SwitchCard(
                leading: const _RoundIcon(
                  icon: Icons.do_not_disturb_on_rounded,
                  color: AppColors.error,
                ),
                title: 'Ne pas déranger',
                subtitle: 'Coupe toutes les notifications',
                value: muted,
                onChanged: (v) => _update(settings.copyWith(doNotDisturb: v)),
              ),
              const SizedBox(height: AppSizes.lg),
              Text('Recevoir', style: context.text.titleMedium),
              const SizedBox(height: 12),
              // Les types sont estompés quand « Ne pas déranger » est actif.
              AnimatedOpacity(
                duration: AppDurations.medium,
                opacity: muted ? 0.45 : 1,
                child: IgnorePointer(
                  ignoring: muted,
                  child: Column(
                    children: [
                      for (final (i, type) in NotificationType.values.indexed)
                        Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SwitchCard(
                                leading: NotificationTypeIcon(
                                  type: type,
                                  size: 40,
                                ),
                                title: type.label,
                                subtitle: type.description,
                                value: settings.isTypeEnabled(type),
                                onChanged: (v) =>
                                    _update(settings.withType(type, v)),
                              ),
                            )
                            .animate(delay: (50 * i).ms)
                            .fadeIn(duration: 300.ms)
                            .slideX(begin: 0.08, end: 0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text('Affichage', style: context.text.titleMedium),
              const SizedBox(height: 12),
              _SwitchCard(
                leading: const _RoundIcon(
                  icon: Icons.web_asset_rounded,
                  color: AppColors.info,
                ),
                title: 'Bannières dans l\'application',
                subtitle: 'Aperçu animé en haut de l\'écran',
                value: settings.inAppBanner,
                onChanged: (v) => _update(settings.copyWith(inAppBanner: v)),
              ),
              const SizedBox(height: 10),
              _SwitchCard(
                leading: const _RoundIcon(
                  icon: Icons.vibration_rounded,
                  color: AppColors.success,
                ),
                title: 'Son et vibration',
                subtitle: 'Vibration légère à la réception',
                value: settings.sound,
                onChanged: (v) => _update(settings.copyWith(sound: v)),
              ),
              const SizedBox(height: AppSizes.lg),
              PrimaryButton(
                label: 'Tester une notification',
                icon: Icons.campaign_rounded,
                onPressed: _test,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
