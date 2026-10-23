import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../data/profile_mock_data.dart';
import '../controllers/profile_controller.dart';

/// Réglages des notifications (interrupteurs animés).
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const _icons = {
    'orders': Icons.delivery_dining_rounded,
    'promos': Icons.local_offer_rounded,
    'news': Icons.storefront_rounded,
    'email': Icons.alternate_email_rounded,
    'sms': Icons.sms_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    final prefs = ProfileMockData.notificationPrefs.entries.toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Notifications'),
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            Text(
              'Choisissez les notifications que vous souhaitez recevoir.',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            for (final (i, entry) in prefs.indexed)
              Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: AppDurations.medium,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: profile.notificationEnabled(entry.key)
                                ? context.colors.primary.withValues(alpha: 0.12)
                                : context.palette.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm,
                            ),
                          ),
                          child: Icon(
                            _icons[entry.key],
                            color: profile.notificationEnabled(entry.key)
                                ? context.colors.primary
                                : context.palette.textSecondary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.$1,
                                style: context.text.titleSmall,
                              ),
                              Text(
                                entry.value.$2,
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: profile.notificationEnabled(entry.key),
                          onChanged: (v) =>
                              profile.setNotification(entry.key, v),
                        ),
                      ],
                    ),
                  )
                  .animate(delay: (50 * i).ms)
                  .fadeIn(duration: 350.ms)
                  .slideX(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }
}
