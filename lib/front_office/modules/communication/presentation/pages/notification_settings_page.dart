import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_form_fields.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../shared/models/models.dart';
import '../../providers/communication_providers.dart';
import 'notifications_page.dart';

/// Préférences de notifications : catégories et canaux.
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  static const _descriptions = {
    NotificationType.order: 'Confirmation, préparation et livraison',
    NotificationType.promo: 'Offres et codes promo',
    NotificationType.message: 'Messages des restaurants et livreurs',
    NotificationType.review: 'Réponses à vos avis',
    NotificationType.system: 'Informations importantes du service',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final channels = ref.watch(notificationChannelsProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children:
              [
                    const PageTitle('Préférences'),
                    const SizedBox(height: AppSizes.lg),
                    Text('Je souhaite recevoir', style: context.text.titleMedium),
                    const SizedBox(height: AppSizes.sm),
                    for (final type in NotificationType.values) ...[
                      AppSwitchField(
                        title: type.label,
                        subtitle: _descriptions[type],
                        icon: NotificationsPage.iconOf(type),
                        value: prefs[type] ?? true,
                        onChanged: (v) => ref
                            .read(notificationPrefsProvider.notifier)
                            .set(type, v),
                      ),
                      const SizedBox(height: AppSizes.sm),
                    ],
                    const SizedBox(height: AppSizes.md),
                    Text('Par', style: context.text.titleMedium),
                    const SizedBox(height: AppSizes.sm),
                    for (final channel in NotificationChannel.values) ...[
                      AppSwitchField(
                        title: channel.label,
                        subtitle: channel.description,
                        icon: switch (channel) {
                          NotificationChannel.push =>
                            Icons.notifications_active_outlined,
                          NotificationChannel.email => Icons.mail_outline_rounded,
                          NotificationChannel.sms => Icons.sms_outlined,
                        },
                        value: channels.contains(channel),
                        onChanged: (v) => ref
                            .read(notificationChannelsProvider.notifier)
                            .toggle(channel, v),
                      ),
                      const SizedBox(height: AppSizes.sm),
                    ],
                  ]
                  .animate(interval: 30.ms)
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }
}
