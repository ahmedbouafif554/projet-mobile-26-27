import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/location/geocoding_service.dart';
import '../../providers/catalog_providers.dart';

/// Demande la position du client. Affiche un message lisible si elle est
/// refusée ou indisponible ; renvoie `true` si elle est connue.
Future<bool> locateCustomer(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(userLocationProvider.notifier).locate();
    return true;
  } on LocationException catch (error) {
    if (context.mounted) _showMessage(context, error.message);
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'Position indisponible pour le moment, réessayez.');
    }
  }
  return false;
}

/// « Près de moi » : active le tri par distance (en demandant la position)
/// ou le désactive (la position est oubliée).
Future<void> toggleNearMe(BuildContext context, WidgetRef ref) async {
  final location = ref.read(userLocationProvider);
  if (location.isLocating) return;
  if (location.position != null) {
    ref.read(userLocationProvider.notifier).clear();
    final filter = ref.read(restaurantFilterProvider);
    if (filter.sort == RestaurantSort.nearest) {
      ref
          .read(restaurantFilterProvider.notifier)
          .update(filter.copyWith(sort: RestaurantSort.recommended));
    }
    return;
  }
  final located = await locateCustomer(context, ref);
  if (!located || !context.mounted) return;
  final filter = ref.read(restaurantFilterProvider);
  ref
      .read(restaurantFilterProvider.notifier)
      .update(filter.copyWith(sort: RestaurantSort.nearest));
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
