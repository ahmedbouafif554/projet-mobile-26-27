import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../catalog/presentation/widgets/catalog_shimmers.dart';
import '../../../communication_routes.dart';
import '../../../models/app_notification.dart';
import '../../controllers/notification_center_controller.dart';
import '../../widgets/notifications/notification_style.dart';
import '../../widgets/notifications/notification_tile.dart';

/// Regroupe une date : « Aujourd'hui », « Hier », « Cette semaine », « Plus ancien ».
String notificationGroup(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  if (diff < 7) return 'Cette semaine';
  return 'Plus ancien';
}

/// Centre de notifications : filtres, groupes par date, glisser pour
/// supprimer (avec annulation) et « tout marquer comme lu ».
class NotificationsCenterPage extends StatefulWidget {
  const NotificationsCenterPage({super.key});

  @override
  State<NotificationsCenterPage> createState() =>
      _NotificationsCenterPageState();
}

class _NotificationsCenterPageState extends State<NotificationsCenterPage> {
  final _center = NotificationCenterController.instance;
  NotificationType? _type;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _center.load();
  }

  List<AppNotification> get _filtered => _center.items
      .where(
        (n) =>
            (_type == null || n.type == _type) && (!_unreadOnly || !n.isRead),
      )
      .toList();

  void _open(AppNotification n) {
    _center.markAsRead(n.id);
    if (n.route != null) context.push(n.route!);
  }

  void _remove(AppNotification n) {
    final index = _center.remove(n);
    AppSnackbar.show(
      context,
      'Notification supprimée',
      icon: Icons.delete_outline_rounded,
      actionLabel: 'Annuler',
      onAction: () => _center.undoRemove(n, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Simuler une notification push',
            onPressed: _center.simulatePush,
            icon: const Icon(Icons.campaign_outlined),
          ),
          IconButton(
            tooltip: 'Réglages',
            onPressed: () =>
                context.push(CommunicationRoutes.notificationSettings),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: _center,
        builder: (context, _) {
          final unread = _center.unreadCount;
          return Column(
            children: [
              _Filters(
                type: _type,
                unreadOnly: _unreadOnly,
                unreadCount: unread,
                onAll: () => setState(() {
                  _type = null;
                  _unreadOnly = false;
                }),
                onUnread: () => setState(() => _unreadOnly = !_unreadOnly),
                onType: (t) => setState(() => _type = _type == t ? null : t),
              ),
              AnimatedSize(
                duration: AppDurations.medium,
                child: unread == 0
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          4,
                          AppSizes.sm,
                          0,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$unread non lue${unread > 1 ? 's' : ''}',
                              style: context.text.bodySmall,
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _center.markAllAsRead,
                              icon: const Icon(
                                Icons.done_all_rounded,
                                size: 18,
                              ),
                              label: const Text('Tout marquer comme lu'),
                            ),
                          ],
                        ),
                      ),
              ),
              Expanded(child: _buildList(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (!_center.hasLoaded && _center.error == null) {
      return const RestaurantListShimmer(count: 6);
    }
    if (!_center.hasLoaded && _center.error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Chargement impossible',
        message: _center.error!,
        actionLabel: 'Réessayer',
        onAction: () => _center.load(force: true),
      );
    }

    final items = _filtered;
    final children = <Widget>[];
    String? group;
    for (final (i, n) in items.indexed) {
      final current = notificationGroup(n.createdAt);
      if (current != group) {
        group = current;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Text(current, style: context.text.titleMedium),
          ),
        );
      }
      children.add(
        Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey('notif-${n.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _remove(n),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSizes.lg),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                child: NotificationTile(notification: n, onTap: () => _open(n)),
              ),
            )
            .animate(
              key: ValueKey('anim-${n.id}'),
              delay: (40 * i.clamp(0, 8)).ms,
            )
            .fadeIn(duration: 350.ms)
            .slideX(begin: 0.08, end: 0),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _center.load(force: true),
      child: items.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 420,
                  child: EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: _unreadOnly
                        ? 'Tout est lu 🎉'
                        : 'Aucune notification',
                    message: 'Les nouvelles notifications apparaîtront ici.',
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.sm,
                AppSizes.pagePadding,
                AppSizes.xl,
              ),
              children: children,
            ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.type,
    required this.unreadOnly,
    required this.unreadCount,
    required this.onAll,
    required this.onUnread,
    required this.onType,
  });

  final NotificationType? type;
  final bool unreadOnly;
  final int unreadCount;
  final VoidCallback onAll;
  final VoidCallback onUnread;
  final ValueChanged<NotificationType> onType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          4,
          AppSizes.pagePadding,
          4,
        ),
        children: [
          SelectableChip(
            label: 'Toutes',
            selected: type == null && !unreadOnly,
            onTap: onAll,
          ),
          const SizedBox(width: 8),
          SelectableChip(
            label: unreadCount > 0 ? 'Non lues ($unreadCount)' : 'Non lues',
            icon: Icons.mark_email_unread_rounded,
            selected: unreadOnly,
            onTap: onUnread,
          ),
          for (final t in NotificationType.values) ...[
            const SizedBox(width: 8),
            SelectableChip(
              label: t.label,
              icon: notificationIcon(t),
              selected: type == t,
              onTap: () => onType(t),
            ),
          ],
        ],
      ),
    );
  }
}
