import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/city_map.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shell/bo_page.dart';
import '../catalog/catalog_controllers.dart';
import 'delivery_actions.dart';
import 'delivery_controllers.dart';

/// Zone affichée (Paris intra-muros, environ).
class _Bounds {
  static const north = 48.888;
  static const south = 48.835;
  static const west = 2.300;
  static const east = 2.405;

  /// Position relative (0–1) d'un point dans la zone.
  static Offset project(double lat, double lng) => Offset(
    ((lng - west) / (east - west)).clamp(0.03, 0.97),
    ((north - lat) / (north - south)).clamp(0.04, 0.96),
  );
}

/// Position de démonstration d'un restaurant (pas de coordonnées dans les
/// données mock) : stable, calculée à partir de son identifiant.
Offset restaurantPosition(Restaurant r) {
  final seed = r.id.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);
  final random = math.Random(seed);
  return Offset(0.12 + random.nextDouble() * 0.76, 0.14 + random.nextDouble() * 0.7);
}

/// Carte en direct (admin) : livreurs, restaurants et courses en cours sur
/// un plan stylisé de Paris. Les livreurs en course se déplacent.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  final Set<CourierStatus> _shown = {...CourierStatus.values};
  bool _showRestaurants = true;
  String? _selectedId;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couriers = (ref.watch(couriersControllerProvider).value ?? [])
        .where((c) => _shown.contains(c.status))
        .toList();
    final restaurants = (ref.watch(restaurantsControllerProvider).value ?? [])
        .where((r) => r.isVisible)
        .toList();
    final deliveries = (ref.watch(deliveriesControllerProvider).value ?? [])
        .where((d) => d.status.isActive)
        .toList();
    final selected = couriers.where((c) => c.id == _selectedId).firstOrNull;

    final filters = Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        for (final status in CourierStatus.values)
          FilterChip(
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: courierColor(status),
            ),
            label: Text(status.label),
            selected: _shown.contains(status),
            onSelected: (on) => setState(
              () => on ? _shown.add(status) : _shown.remove(status),
            ),
          ),
        FilterChip(
          avatar: const Icon(
            Icons.storefront_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          label: const Text('Restaurants'),
          selected: _showRestaurants,
          onSelected: (on) => setState(() => _showRestaurants = on),
        ),
      ],
    );

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final t = _motion.value * 2 * math.pi;
              Offset courierPoint(Courier c) {
                var p = _Bounds.project(c.latitude, c.longitude);
                // Les livreurs en course bougent légèrement (démo).
                if (c.status == CourierStatus.busy) {
                  final phase = c.id.hashCode % 10;
                  p += Offset(
                    math.cos(t + phase) * 0.025,
                    math.sin(t + phase) * 0.018,
                  );
                }
                return Offset(p.dx * size.width, p.dy * size.height);
              }

              final routes = <(Offset, Offset)>[];
              for (final d in deliveries) {
                final courier = couriers
                    .where((c) => c.id == d.courierId)
                    .firstOrNull;
                final restaurant = restaurants
                    .where((r) => r.name == d.pickupName)
                    .firstOrNull;
                if (courier == null || restaurant == null) continue;
                final rp = restaurantPosition(restaurant);
                routes.add((
                  Offset(rp.dx * size.width, rp.dy * size.height),
                  courierPoint(courier),
                ));
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedId = null),
                      child: CustomPaint(
                        painter: CityMapPainter(
                          dark: context.isDark,
                          routes: routes,
                          dash: _motion.value,
                        ),
                      ),
                    ),
                  ),
                  if (_showRestaurants)
                    for (final r in restaurants)
                      _placed(
                        restaurantPosition(r).scale(size.width, size.height),
                        _RestaurantPin(restaurant: r),
                        width: 34,
                        height: 40,
                        anchorBottom: true,
                      ),
                  for (final c in couriers)
                    _placed(
                      courierPoint(c),
                      _CourierMarker(
                        courier: c,
                        selected: c.id == _selectedId,
                        onTap: () => setState(() => _selectedId = c.id),
                      ),
                      width: 52,
                      height: 52,
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _Legend(
                      online: couriers
                          .where((c) => c.status.isOnline)
                          .length,
                      active: deliveries.length,
                    ),
                  ),
                  if (selected != null)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _CourierCard(
                        courier: selected,
                        delivery: deliveries
                            .where((d) => d.courierId == selected.id)
                            .firstOrNull,
                        onClose: () => setState(() => _selectedId = null),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );

    return BoPage(
      title: 'Carte en direct',
      subtitle: 'Position des livreurs et courses en cours.',
      scrollable: false,
      children: [
        filters,
        const SizedBox(height: AppSizes.md),
        Expanded(child: map),
      ],
    );
  }

  Widget _placed(
    Offset point,
    Widget child, {
    required double width,
    required double height,
    bool anchorBottom = false,
  }) => Positioned(
    left: point.dx - width / 2,
    top: anchorBottom ? point.dy - height : point.dy - height / 2,
    width: width,
    height: height,
    child: child,
  );
}

class _RestaurantPin extends StatelessWidget {
  const _RestaurantPin({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${restaurant.name}\n${restaurant.address}',
      child: InkWell(
        onTap: () => context.go(BackRoutes.restaurant(restaurant.id)),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: restaurant.isOpen
                    ? AppColors.primary
                    : AppColors.textSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            CustomPaint(size: const Size(10, 8), painter: _PinTip()),
          ],
        ),
      ),
    );
  }
}

class _PinTip extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CourierMarker extends StatelessWidget {
  const _CourierMarker({
    required this.courier,
    required this.selected,
    required this.onTap,
  });

  final Courier courier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = courierColor(courier.status);
    final marker = GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: EdgeInsets.all(selected ? 4 : 3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: selected ? 16 : 8,
              ),
            ],
          ),
          child: Avatar(
            name: courier.fullName,
            imageUrl: courier.avatarUrl,
            size: selected ? 40 : 34,
          ),
        ),
      ),
    );
    return Tooltip(
      message: '${courier.fullName} • ${courier.status.label}',
      child: MouseRegion(cursor: SystemMouseCursors.click, child: marker),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.online, required this.active});

  final int online;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: context.palette.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
            begin: 0.3,
            duration: 800.ms,
          ),
          const SizedBox(width: 8),
          Text('$online en ligne', style: context.text.labelLarge),
          const SizedBox(width: 14),
          const Icon(Icons.route_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$active course(s)', style: context.text.labelLarge),
        ],
      ),
    );
  }
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({
    required this.courier,
    required this.delivery,
    required this.onClose,
  });

  final Courier courier;
  final Delivery? delivery;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = courier;
    return SizedBox(
      width: 290,
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(name: c.fullName, imageUrl: c.avatarUrl, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.fullName, style: context.text.titleSmall),
                      Text(
                        '${c.vehicle.label} • ★ ${Formatters.rating(c.rating)}',
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: courierStatusChip(c.status),
            ),
            if (delivery != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(
                'Course #${delivery!.orderReference} • ${delivery!.status.label}\n'
                '${delivery!.pickupName} → ${delivery!.customerName}',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            FilledButton.tonal(
              onPressed: () => context.go(BackRoutes.courier(c.id)),
              child: const Text('Voir la fiche'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.1, end: 0);
  }
}
