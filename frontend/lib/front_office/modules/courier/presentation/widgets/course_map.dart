import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/location/road_route.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../shared/models/models.dart';
import '../../providers/courier_gps.dart';

/// Vitesse moyenne en ville (km/h) et facteur routier : mêmes règles que
/// l'estimation du serveur.
const _citySpeedKmh = 30.0;
const _roadFactor = 1.3;

/// Prochain arrêt de la course : le restaurant avant le retrait, le client
/// ensuite.
({LatLng? point, String label, IconData icon}) nextStop(Delivery d) =>
    d.status == DeliveryStatus.assigned || d.status == DeliveryStatus.waiting
    ? (
        point: _point(d.pickupLat, d.pickupLng),
        label: d.pickupName,
        icon: Icons.storefront_rounded,
      )
    : (
        point: _point(d.dropoffLat, d.dropoffLng),
        label: d.customerName,
        icon: Icons.home_rounded,
      );

LatLng? _point(double? lat, double? lng) =>
    lat == null || lng == null ? null : LatLng(lat, lng);

/// Distance (km) et durée (min) entre la position GPS du livreur et son
/// prochain arrêt ; null sans GPS.
({double km, int minutes})? legFromMe(WidgetRef ref, Delivery d) {
  final me = ref.watch(myGpsPositionProvider);
  final target = nextStop(d).point;
  if (me == null || target == null) return null;
  final km =
      const Distance().as(LengthUnit.Meter, LatLng(me.lat, me.lng), target) /
      1000;
  final minutes = (km * _roadFactor / _citySpeedKmh * 60).round();
  return (km: km, minutes: minutes < 1 ? 1 : minutes);
}

/// Vraie carte (OpenStreetMap) de la course : restaurant, client, position
/// GPS du livreur et itinéraire routier de l'étape en cours.
class CourseMap extends ConsumerStatefulWidget {
  const CourseMap({super.key, required this.delivery, this.height = 240});

  final Delivery delivery;
  final double height;

  @override
  ConsumerState<CourseMap> createState() => _CourseMapState();
}

class _CourseMapState extends ConsumerState<CourseMap> {
  final _map = MapController();
  bool _ready = false;
  bool _fitted = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fit(List<LatLng> points) {
    if (!_ready || _fitted || points.isEmpty) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (points.length == 1) {
          _map.move(points.first, 15);
        } else {
          _map.fitCamera(
            CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(40),
              maxZoom: 17,
            ),
          );
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final pickup = _point(d.pickupLat, d.pickupLng);
    final dropoff = _point(d.dropoffLat, d.dropoffLng);
    final gps = ref.watch(myGpsPositionProvider);
    final me = gps == null ? null : LatLng(gps.lat, gps.lng);
    final target = nextStop(d).point;

    // Étape en cours : moi → prochain arrêt (sinon restaurant → client).
    final rounded = me == null ? null : roundedPoint(me.latitude, me.longitude);
    final ends = rounded != null && target != null && d.status.isActive
        ? (rounded, target)
        : (pickup != null && dropoff != null ? (pickup, dropoff) : null);
    final route = ends == null
        ? null
        : ref.watch(roadRouteProvider(ends)).value;

    final points = [?pickup, ?dropoff, ?me];
    _fit(points);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: points.isEmpty
            ? ColoredBox(
                color: context.palette.surfaceMuted,
                child: const Center(child: Text('Position indisponible')),
              )
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: me ?? pickup ?? dropoff!,
                      initialZoom: 14,
                      onMapReady: () {
                        _ready = true;
                        _fit(points);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.superfaster.app',
                      ),
                      if (route != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route,
                              strokeWidth: 5,
                              color: AppColors.primary.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (pickup != null)
                            Marker(
                              point: pickup,
                              width: 40,
                              height: 40,
                              child: _pin(
                                Icons.storefront_rounded,
                                AppColors.primary,
                              ),
                            ),
                          if (dropoff != null)
                            Marker(
                              point: dropoff,
                              width: 40,
                              height: 40,
                              child: _pin(
                                Icons.home_rounded,
                                AppColors.success,
                              ),
                            ),
                          if (me != null)
                            Marker(
                              point: me,
                              width: 26,
                              height: 26,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: context.colors.surface,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: 'Recentrer',
                        icon: const Icon(Icons.my_location_rounded),
                        onPressed: () {
                          _fitted = false;
                          _fit(points);
                        },
                      ),
                    ),
                  ),
                  if (me == null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Activez la localisation pour vous voir',
                          style: context.text.labelSmall,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _pin(IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
    child: Icon(icon, color: Colors.white, size: 18),
  );
}

/// « Restaurant à 1,2 km · ~4 min » depuis la position du livreur.
class NextStopBanner extends ConsumerWidget {
  const NextStopBanner({super.key, required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stop = nextStop(delivery);
    final leg = legFromMe(ref, delivery);
    final arrival = leg == null
        ? null
        : DateTime.now().add(Duration(minutes: leg.minutes));
    return Row(
      children: [
        Icon(stop.icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                delivery.status == DeliveryStatus.assigned
                    ? 'Direction le restaurant'
                    : 'Direction le client',
                style: context.text.labelSmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              Text(stop.label, style: context.text.titleSmall),
            ],
          ),
        ),
        if (leg != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${leg.minutes} min',
                style: context.text.titleMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${Formatters.distance(leg.km)} • ${Formatters.time(arrival!)}',
                style: context.text.labelSmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          )
        else
          Text(
            'GPS…',
            style: context.text.labelSmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
      ],
    );
  }
}
