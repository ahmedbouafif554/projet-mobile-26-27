import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../communication_routes.dart';
import '../../controllers/notification_center_controller.dart';

/// Cloche avec compteur de non lues : le badge rebondit à chaque changement
/// et la cloche « sonne » quand une nouvelle notification arrive.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.elevated = false});

  final bool elevated;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  final _center = NotificationCenterController.instance;
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late int _lastCount = _center.unreadCount;

  @override
  void initState() {
    super.initState();
    _center.addListener(_onChange);
    _center.load();
  }

  void _onChange() {
    final count = _center.unreadCount;
    if (count > _lastCount) _ring.forward(from: 0);
    _lastCount = count;
    setState(() {});
  }

  @override
  void dispose() {
    _center.removeListener(_onChange);
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _center.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _ring,
          // Oscillation amortie autour du haut de la cloche.
          builder: (context, child) => Transform.rotate(
            angle:
                math.sin(_ring.value * math.pi * 8) * 0.35 * (1 - _ring.value),
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: CircleIconButton(
            icon: count > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            elevated: widget.elevated,
            tooltip: 'Notifications',
            onTap: () => context.push(CommunicationRoutes.notifications),
          ),
        ),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child:
                Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.favorite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.colors.surface,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: context.text.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    // La clé change avec le nombre : le rebond est rejoué.
                    .animate(key: ValueKey(count))
                    .scaleXY(
                      begin: 0.3,
                      end: 1,
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),
          ),
      ],
    );
  }
}
