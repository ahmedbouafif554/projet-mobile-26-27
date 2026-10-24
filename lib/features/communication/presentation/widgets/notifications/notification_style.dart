import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../models/app_notification.dart';

/// Icône d'un type de notification.
IconData notificationIcon(NotificationType type) => switch (type) {
  NotificationType.order => Icons.delivery_dining_rounded,
  NotificationType.chat => Icons.chat_bubble_rounded,
  NotificationType.review => Icons.star_rounded,
  NotificationType.promo => Icons.local_offer_rounded,
  NotificationType.system => Icons.campaign_rounded,
};

/// Couleur d'un type de notification.
Color notificationColor(NotificationType type) => switch (type) {
  NotificationType.order => AppColors.success,
  NotificationType.chat => AppColors.info,
  NotificationType.review => AppColors.warning,
  NotificationType.promo => AppColors.primary,
  NotificationType.system => const Color(0xFF8B5CF6),
};

/// Pastille ronde colorée avec l'icône du type.
class NotificationTypeIcon extends StatelessWidget {
  const NotificationTypeIcon({super.key, required this.type, this.size = 42});

  final NotificationType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = notificationColor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(notificationIcon(type), color: color, size: size * 0.5),
    );
  }
}
