import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../providers/communication_providers.dart';

/// Notifications regroupées par date, balayer pour supprimer (avec
/// « Annuler »), toucher pour ouvrir l'écran concerné.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static String _group(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff < 7) return 'Cette semaine';
    return 'Plus ancien';
  }

  static IconData iconOf(NotificationType type) => switch (type) {
    NotificationType.order => Icons.receipt_long_rounded,
    NotificationType.promo => Icons.local_offer_rounded,
    NotificationType.message => Icons.chat_bubble_rounded,
    NotificationType.review => Icons.star_rounded,
    NotificationType.system => Icons.info_rounded,
  };

  static Color colorOf(NotificationType type) => switch (type) {
    NotificationType.order => AppColors.primary,
    NotificationType.promo => AppColors.favorite,
    NotificationType.message => AppColors.info,
    NotificationType.review => AppColors.warning,
    NotificationType.system => AppColors.success,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final prefs = ref.watch(notificationPrefsProvider);
    final controller = ref.read(notificationsProvider.notifier);
    final list = (notifications.value ?? const <AppNotification>[])
        .where((n) => prefs[n.type] ?? true)
        .toList();
    final unread = list.where((n) => !n.isRead).length;

    final grouped = <String, List<AppNotification>>{};
    for (final n in list) {
      grouped.putIfAbsent(_group(n.createdAt), () => []).add(n);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.sm,
                AppSizes.sm,
              ),
              child: Row(
                children: [
                  const Expanded(child: PageTitle('Notifications')),
                  IconButton(
                    tooltip: 'Préférences',
                    onPressed: () =>
                        context.push(FrontRoutes.notificationSettings),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$unread non lue${unread > 1 ? 's' : ''}',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: controller.markAllRead,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Tout marquer comme lu'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: notifications.isLoading && notifications.value == null
                  ? ShimmerScope(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSizes.pagePadding),
                        children: [
                          for (var i = 0; i < 5; i++)
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppSizes.sm),
                              child: SkeletonBox(height: 76),
                            ),
                        ],
                      ),
                    )
                  : list.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'Aucune notification',
                      message: 'Vous êtes à jour !',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.pagePadding,
                        AppSizes.sm,
                        AppSizes.pagePadding,
                        AppSizes.xl,
                      ),
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSizes.md,
                              bottom: AppSizes.sm,
                            ),
                            child: Text(
                              entry.key,
                              style: context.text.titleSmall?.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ),
                          for (final (i, n) in entry.value.indexed)
                            _NotificationTile(key: ValueKey(n.id), notification: n)
                                .animate(delay: (30 * i).ms)
                                .fadeIn()
                                .slideX(begin: 0.04, end: 0),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final controller = ref.read(notificationsProvider.notifier);
    final color = NotificationsPage.colorOf(n.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Dismissible(
        key: ValueKey('n-${n.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        onDismissed: (_) async {
          await controller.remove(n);
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            'Notification supprimée',
            icon: Icons.delete_outline_rounded,
            actionLabel: 'Annuler',
            onAction: () => controller.restore(n),
          );
        },
        child: Material(
          color: n.isRead
              ? context.colors.surface
              : AppColors.primary.withValues(alpha: context.isDark ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: () {
              controller.markRead(n);
              final route = n.route;
              if (route != null) context.push(route);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      NotificationsPage.iconOf(n.type),
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: context.text.titleSmall?.copyWith(
                                  fontWeight: n.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              Formatters.relative(n.createdAt),
                              style: context.text.labelSmall?.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          n.body,
                          style: context.text.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!n.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
