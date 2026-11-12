import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Itinéraire routier entre deux points (OSRM, OpenStreetMap). En cas
/// d'échec (hors ligne, service saturé) : ligne droite entre les deux.
final roadRouteProvider = FutureProvider.autoDispose
    .family<List<LatLng>, (LatLng, LatLng)>((ref, ends) async {
      final (from, to) = ends;
      try {
        final response =
            await Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
              ),
            ).get<Map<String, dynamic>>(
              'https://router.project-osrm.org/route/v1/driving/'
              '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
              queryParameters: {'overview': 'full', 'geometries': 'geojson'},
            );
        final routes = response.data?['routes'] as List?;
        final coords =
            (routes?.first as Map?)?['geometry']?['coordinates'] as List?;
        if (coords == null || coords.isEmpty) return [from, to];
        return [
          for (final c in coords)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ];
      } catch (_) {
        return [from, to];
      }
    });

/// Arrondi d'une position GPS (~10 m) : l'itinéraire n'est pas recalculé à
/// chaque petit mouvement du livreur.
LatLng roundedPoint(double lat, double lng) => LatLng(
  (lat * 10000).roundToDouble() / 10000,
  (lng * 10000).roundToDouble() / 10000,
);
