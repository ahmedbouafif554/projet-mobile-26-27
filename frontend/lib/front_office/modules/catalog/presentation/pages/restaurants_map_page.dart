import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../providers/catalog_providers.dart';
import '../widgets/near_me.dart';

/// Restaurants localisés sur une carte OpenStreetMap, avec les filtres de la
/// liste et la position du client. Un repère affiche le restaurant, sa fiche
/// s'ouvre d'un toucher.
class RestaurantsMapPage extends ConsumerStatefulWidget {
  const RestaurantsMapPage({super.key});

  /// Centre de Paris, quand aucun restaurant n'est localisé.
  static const fallbackCenter = LatLng(48.8566, 2.3522);

  @override
  ConsumerState<RestaurantsMapPage> createState() =>
      _RestaurantsMapPageState();
}

class _RestaurantsMapPageState extends ConsumerState<RestaurantsMapPage> {
  final _map = MapController();
  String? _selectedId;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Demande la position du client puis centre la carte sur lui.
  Future<void> _locate() async {
    if (!await locateCustomer(context, ref) || !mounted) return;
    final position = ref.read(userLocationProvider).position;
    if (position != null) _map.move(position, 15);
  }

  /// Centre des restaurants affichés.
  static LatLng _centerOf(List<Restaurant> restaurants) {
    if (restaurants.isEmpty) return RestaurantsMapPage.fallbackCenter;
    final latitude = restaurants.fold<double>(0, (s, r) => s + r.latitude!);
    final longitude = restaurants.fold<double>(0, (s, r) => s + r.longitude!);
    return LatLng(latitude / restaurants.length, longitude / restaurants.length);
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantsProvider);
    final filter = ref.watch(restaurantFilterProvider);
    final location = ref.watch(userLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants sur la carte'),
        actions: [
          IconButton(
            tooltip: 'Ma position',
            onPressed: location.isLocating ? null : _locate,
            icon: location.isLocating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: AsyncValueView(
        value: restaurants,
        onRetry: () => ref.invalidate(restaurantsProvider),
        data: (all) {
          final located = [
            for (final r in filter.apply(all))
              if (r.hasLocation) r,
          ];
          final selected = located.where((r) => r.id == _selectedId);
          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: location.position ?? _centerOf(located),
                  initialZoom: 13,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, _) => setState(() => _selectedId = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.superfaster.app',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final r in located)
                        Marker(
                          point: LatLng(r.latitude!, r.longitude!),
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: _RestaurantPin(
                            restaurant: r,
                            selected: r.id == _selectedId,
                            onTap: () => setState(() => _selectedId = r.id),
                          ),
                        ),
                      if (location.position != null)
                        Marker(
                          point: location.position!,
                          width: 22,
                          height: 22,
                          child: const _CustomerDot(),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© les contributeurs d’OpenStreetMap',
                      ),
                    ],
                  ),
                ],
              ),
              if (located.isEmpty)
                Positioned(
                  left: AppSizes.pagePadding,
                  right: AppSizes.pagePadding,
                  top: AppSizes.md,
                  child: _Banner(
                    all.isEmpty
                        ? 'Aucun restaurant pour le moment.'
                        : 'Aucun restaurant localisé avec ces filtres.',
                  ),
                ),
              if (selected.isNotEmpty)
                Positioned(
                  left: AppSizes.pagePadding,
                  right: AppSizes.pagePadding,
                  bottom: AppSizes.xl + AppSizes.lg,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    clipBehavior: Clip.antiAlias,
                    child: RestaurantTile(
                      restaurant: selected.first,
                      onTap: () => context.push(
                        FrontRoutes.restaurant(selected.first.id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Repère d'un restaurant (fermé : grisé ; sélectionné : agrandi).
class _RestaurantPin extends StatelessWidget {
  const _RestaurantPin({
    required this.restaurant,
    required this.selected,
    required this.onTap,
  });

  final Restaurant restaurant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: restaurant.name,
    child: GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_on_rounded,
        size: selected ? 44 : 36,
        color: restaurant.isOpen ? AppColors.primary : Colors.grey,
        shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
      ),
    ),
  );
}

/// Position du client (point bleu).
class _CustomerDot extends StatelessWidget {
  const _CustomerDot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.blue,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.colors.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: context.text.bodySmall,
    ),
  );
}
