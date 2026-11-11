import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';

/// Actions vers les applications du téléphone : appel et itinéraire GPS.
class Launcher {
  Launcher._();

  /// Ouvre le composeur avec le numéro (l'utilisateur confirme l'appel).
  static Future<void> call(BuildContext context, String? phone) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      AppSnackbar.info(context, 'Numéro de téléphone indisponible.');
      return;
    }
    await _open(context, Uri(scheme: 'tel', path: digits));
  }

  /// Itinéraire dans l'application de navigation (Google Maps, Waze…).
  static Future<void> navigate(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final hasPoint = latitude != null && longitude != null;
    if (!hasPoint && (address == null || address.trim().isEmpty)) {
      AppSnackbar.info(context, 'Adresse indisponible.');
      return;
    }
    final destination = hasPoint ? '$latitude,$longitude' : address!.trim();
    await _open(
      context,
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': destination,
        'travelmode': 'driving',
      }),
    );
  }

  static Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && context.mounted) {
      AppSnackbar.error(context, "Impossible d'ouvrir l'application.");
    }
  }
}
