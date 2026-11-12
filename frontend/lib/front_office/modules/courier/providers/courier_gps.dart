import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/models.dart';
import 'courier_providers.dart';

/// Course en cours du livreur connecté (assignée, récupérée ou en route).
/// Un record (égalité par valeur) : le suivi GPS ne redémarre pas à chaque
/// rechargement de la liste.
final activeCourierDeliveryProvider =
    Provider<({String id, String courierId})?>((ref) {
      final deliveries = ref.watch(myDeliveriesProvider).value ?? const [];
      for (final d in deliveries) {
        final courierId = d.courierId;
        if (courierId != null &&
            (d.status == DeliveryStatus.assigned ||
                d.status == DeliveryStatus.pickedUp ||
                d.status == DeliveryStatus.inTransit)) {
          return (id: d.id, courierId: courierId);
        }
      }
      return null;
    });

/// Dernière position GPS du téléphone du livreur (carte de la course,
/// distances « à X km de vous »). Null tant que le GPS n'a rien donné.
final myGpsPositionProvider =
    NotifierProvider<MyGpsPosition, ({double lat, double lng})?>(
      MyGpsPosition.new,
    );

class MyGpsPosition extends Notifier<({double lat, double lng})?> {
  @override
  ({double lat, double lng})? build() => null;

  void set(double lat, double lng) => state = (lat: lat, lng: lng);
}

/// Livreur en ligne (disponible ou en course) : son identifiant, sinon null.
final _onlineCourierIdProvider = Provider<String?>((ref) {
  final courier = ref.watch(myCourierProvider).value;
  if (courier == null || courier.status == CourierStatus.offline) return null;
  return courier.id;
});

/// Tant que le livreur est EN LIGNE, son téléphone envoie sa position GPS au
/// serveur (`POST /couriers/:id/location`) :
/// - sans course : le serveur sait où il est (courses proches, distance au
///   restaurant, position de départ réelle à l'acceptation) ;
/// - pendant une course : la position est transmise en direct au client.
///
/// Envoi dès qu'il bouge de 10 m (au plus toutes les 3 s en course, 15 s
/// sinon), et au moins toutes les 20 s à l'arrêt.
final courierGpsTrackerProvider = Provider<void>((ref) {
  final role = ref.watch(authServiceProvider.select((a) => a.role));
  if (role != UserRole.courier) return;
  if (AppConfig.useMockData && !AppConfig.useApiOrders) return;

  final courierId = ref.watch(_onlineCourierIdProvider);
  if (courierId == null) return;

  StreamSubscription<Position>? subscription;
  Timer? heartbeat;
  Position? last;
  DateTime lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  var disposed = false;

  Future<void> send(Position p, {bool force = false}) async {
    final deliveryId = ref.read(activeCourierDeliveryProvider)?.id;
    final minGap = deliveryId != null
        ? const Duration(seconds: 3)
        : const Duration(seconds: 15);
    final now = DateTime.now();
    if (!force && now.difference(lastSent) < minGap) return;
    lastSent = now;
    try {
      await ref
          .read(dioProvider)
          .post(
            '/couriers/$courierId/location',
            data: {
              'latitude': p.latitude,
              'longitude': p.longitude,
              'accuracy': p.accuracy,
              'deliveryId': ?deliveryId,
            },
          );
    } catch (e) {
      if (kDebugMode) debugPrint('[gps] envoi impossible : $e');
    }
  }

  void onPosition(Position p, {bool force = false}) {
    if (disposed) return;
    last = p;
    ref.read(myGpsPositionProvider.notifier).set(p.latitude, p.longitude);
    send(p, force: force);
  }

  // Course acceptée : la position part tout de suite (le client voit le
  // livreur sans attendre qu'il bouge).
  ref.listen(activeCourierDeliveryProvider, (previous, next) {
    final p = last;
    if (next != null && next != previous && p != null) send(p, force: true);
  });

  Future<void> start() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (disposed) return;
      // Position connue immédiatement (si le téléphone en a une), puis précise.
      final known = await Geolocator.getLastKnownPosition();
      if (known != null) onPosition(known, force: true);
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      onPosition(first, force: true);
      if (disposed) return;
      subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(onPosition);
      heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
        final p = last;
        if (p != null) send(p, force: true);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[gps] indisponible : $e');
    }
  }

  start();
  ref.onDispose(() {
    disposed = true;
    subscription?.cancel();
    heartbeat?.cancel();
  });
});
