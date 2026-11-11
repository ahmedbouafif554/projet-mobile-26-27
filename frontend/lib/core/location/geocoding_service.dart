import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Adresse trouvée pour une position (ou l'inverse).
class GeocodedAddress {
  const GeocodedAddress({
    required this.position,
    this.street = '',
    this.postalCode = '',
    this.city = '',
  });

  final LatLng position;
  final String street;
  final String postalCode;
  final String city;

  /// « 12 Rue de la Paix, 75002 Paris »
  String get label => [
    street,
    [postalCode, city].where((s) => s.isNotEmpty).join(' '),
  ].where((s) => s.isNotEmpty).join(', ');
}

/// Erreur lisible pour l'utilisateur (position ou recherche impossible).
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Géocodage OpenStreetMap (Nominatim, gratuit et sans clé) et position GPS
/// du téléphone. Client réseau séparé de l'API : aucun jeton n'est envoyé.
class GeocodingService {
  GeocodingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              // Le navigateur interdit de changer l'User-Agent (web).
              headers: kIsWeb
                  ? null
                  : {
                      'User-Agent':
                          'SuperFaster/1.0 (application de livraison)',
                    },
            ),
          );

  final Dio _dio;

  /// Adresse la plus proche d'une position (null si rien de trouvé).
  Future<GeocodedAddress?> reverse(LatLng position) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': position.latitude,
          'lon': position.longitude,
          'addressdetails': 1,
          'accept-language': 'fr',
        },
      );
      final data = response.data;
      if (data == null || data['address'] is! Map) return null;
      return _fromNominatim(data, fallback: position);
    } on DioException {
      return null;
    }
  }

  /// Position d'une adresse saisie (première correspondance).
  Future<GeocodedAddress?> search(String query) async {
    if (query.trim().length < 3) return null;
    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'format': 'jsonv2',
          'q': query.trim(),
          'limit': 1,
          'addressdetails': 1,
          'accept-language': 'fr',
        },
      );
      final first = response.data?.firstOrNull;
      if (first is! Map<String, dynamic>) return null;
      return _fromNominatim(first);
    } on DioException {
      return null;
    }
  }

  static GeocodedAddress _fromNominatim(
    Map<String, dynamic> data, {
    LatLng? fallback,
  }) {
    final a = (data['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lat = double.tryParse('${data['lat']}');
    final lon = double.tryParse('${data['lon']}');
    final road = a['road'] ?? a['pedestrian'] ?? a['footway'] ?? a['square'];
    final street = [
      a['house_number'],
      road,
    ].where((s) => s != null && '$s'.isNotEmpty).join(' ');
    final city =
        a['city'] ?? a['town'] ?? a['village'] ?? a['municipality'] ?? '';
    return GeocodedAddress(
      position: lat != null && lon != null
          ? LatLng(lat, lon)
          : (fallback ?? const LatLng(0, 0)),
      street: street,
      postalCode: '${a['postcode'] ?? ''}',
      city: '$city',
    );
  }

  /// Position GPS actuelle du téléphone (demande l'autorisation si besoin).
  Future<LatLng> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Activez la localisation de votre téléphone.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Autorisez l’accès à votre position pour vous localiser.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}
