import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../models/app_notification.dart';
import 'notification_style.dart';

/// Ligne du centre de notifications ; les non lues sont mises en avant.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead
              ? context.colors.surface
              : AppColors.primary.withValues(
                  alpha: context.isDark ? 0.12 : 0.05,
                ),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: n.isRead
                ? context.palette.border
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationTypeIcon(type: n.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(n.body, style: context.text.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    '${n.type.label} • ${Formatters.relative(n.createdAt)}',
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: n.isRead ? 0 : 1,
              duration: AppDurations.medium,
              curve: Curves.easeOutBack,
              child: Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4, left: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
