import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../models/app_notification.dart';
import '../../controllers/notification_center_controller.dart';
import 'notification_style.dart';

/// Affiche par-dessus toute l'application les bannières in-app
/// qui simulent une notification push : elles descendent du haut de l'écran,
/// disparaissent seules après quelques secondes ou d'un glissement vers le haut.
class InAppBannerHost extends StatefulWidget {
  const InAppBannerHost({
    super.key,
    required this.child,
    required this.onOpen,
    this.currentLocation,
  });

  final Widget child;

  /// Ouvre la page liée à la notification (fournie par le routeur).
  final ValueChanged<String> onOpen;

  /// Page actuellement affichée : pas de bannière si l'utilisateur y est déjà.
  final String Function()? currentLocation;

  @override
  State<InAppBannerHost> createState() => _InAppBannerHostState();
}

class _InAppBannerHostState extends State<InAppBannerHost> {
  static const _visibleFor = Duration(seconds: 4);

  late final StreamSubscription<AppNotification> _subscription;
  final List<AppNotification> _queue = [];
  AppNotification? _current;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationCenterController.instance.banners.listen(
      _enqueue,
    );
  }

  void _enqueue(AppNotification notification) {
    if (notification.route != null &&
        notification.route == widget.currentLocation?.call()) {
      return;
    }
    _queue.add(notification);
    if (_current == null) _showNext();
  }

  void _showNext() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _current = _queue.isEmpty ? null : _queue.removeAt(0));
    if (_current != null) _hideTimer = Timer(_visibleFor, _dismiss);
  }

  void _dismiss() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _current = null);
    // Laisse la bannière sortir avant d'afficher la suivante.
    if (_queue.isNotEmpty) Timer(AppDurations.medium, _showNext);
  }

  void _open(AppNotification notification) {
    _dismiss();
    NotificationCenterController.instance.markAsRead(notification.id);
    final route = notification.route;
    if (route != null) widget.onOpen(route);
  }

  @override
  void dispose() {
    _subscription.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: AppDurations.medium,
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, -1.4),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: current == null
                  ? const SizedBox(width: double.infinity)
                  : _Banner(
                      key: ValueKey(current.id),
                      notification: current,
                      duration: _visibleFor,
                      onTap: () => _open(current),
                      onDismissed: _dismiss,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.notification,
    required this.duration,
    required this.onTap,
    required this.onDismissed,
  });

  final AppNotification notification;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final n = notification;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: Dismissible(
          key: ValueKey('banner-${n.id}'),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismissed(),
          child: Pressable(
            onTap: onTap,
            scale: 0.97,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: context.palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                    child: Row(
                      children: [
                        NotificationTypeIcon(type: n.type, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'SuperFaster',
                                    style: context.text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    ' • maintenant',
                                    style: context.text.labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.title,
                                style: context.text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                n.body,
                                style: context.text.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.palette.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  // Barre de temps restant avant disparition.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: 0),
                    duration: duration,
                    builder: (context, value, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 3,
                          color: notificationColor(n.type),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
