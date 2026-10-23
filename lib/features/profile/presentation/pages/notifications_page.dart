import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/pressable.dart';
import '../../models/app_notification.dart';
import '../controllers/notifications_controller.dart';

/// Centre de notifications : non lues mises en avant, glisser pour supprimer.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = NotificationsController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;
        final today = items
            .where((n) => DateTime.now().difference(n.date).inHours < 24)
            .toList();
        final earlier = items.where((n) => !today.contains(n)).toList();
        var index = 0;

        Widget tile(AppNotification n) =>
            Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey('dismiss-${n.id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => controller.remove(n.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSizes.lg),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                      ),
                    ),
                    child: _NotificationTile(
                      notification: n,
                      onTap: () {
                        controller.markRead(n.id);
                        if (n.route != null) context.push(n.route!);
                      },
                    ),
                  ),
                )
                .animate(
                  key: ValueKey('anim-${n.id}'),
                  delay: (50 * index++).ms,
                )
                .fadeIn(duration: 350.ms)
                .slideX(begin: 0.1, end: 0);

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 68,
            leading: const Center(child: AppBackButton()),
            title: const Text('Notifications'),
            actions: [
              if (controller.unreadCount > 0)
                TextButton(
                  onPressed: controller.markAllRead,
                  child: const Text('Tout lire'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'Aucune notification',
                  message:
                      'Vous êtes à jour ! Les nouvelles notifications apparaîtront ici.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSizes.pagePadding),
                  children: [
                    if (today.isNotEmpty) ...[
                      const _GroupTitle("Aujourd'hui"),
                      for (final n in today) tile(n),
                    ],
                    if (earlier.isNotEmpty) ...[
                      const _GroupTitle('Plus tôt'),
                      for (final n in earlier) tile(n),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(text, style: context.text.titleMedium),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, color) = switch (n.kind) {
      NotificationKind.order => (
        Icons.delivery_dining_rounded,
        AppColors.success,
      ),
      NotificationKind.promo => (Icons.local_offer_rounded, AppColors.primary),
      NotificationKind.info => (Icons.campaign_rounded, AppColors.info),
    };

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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
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
                    Formatters.relative(n.date),
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
