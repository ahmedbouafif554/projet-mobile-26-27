import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/repositories/repository_providers.dart';

/// Chiffres affichés sous la carte du profil (selon le rôle).
class ProfileStats {
  const ProfileStats(this.items);

  /// (valeur, libellé) — ex. ('12', 'Commandes').
  final List<(String, String)> items;
}

/// Statistiques du profil : commandes, favoris et points pour un client ;
/// courses, note et gains pour un livreur.
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final user = ref.watch(authServiceProvider).user;
  if (user == null) return const ProfileStats([]);

  if (user.role == UserRole.courier) {
    final courier = await ref
        .watch(courierRepositoryProvider)
        .findByUser(user.id);
    return ProfileStats([
      ('${courier?.completedDeliveries ?? 0}', 'Courses'),
      ((courier?.rating ?? 5).toStringAsFixed(1).replaceAll('.', ','), 'Note'),
      ('${(courier?.totalEarnings ?? 0).round()} €', 'Gains'),
    ]);
  }

  final (orders, favorites) = await (
    ref.watch(orderRepositoryProvider).forUser(user.id),
    ref.watch(favoriteRepositoryProvider).getRestaurantIds(user.id),
  ).wait;
  return ProfileStats([
    ('${orders.length}', 'Commandes'),
    ('${favorites.length}', 'Favoris'),
    ('${user.loyaltyPoints}', 'Points'),
  ]);
});

/// Modification du profil de l'utilisateur connecté.
final profileControllerProvider = Provider<ProfileController>(
  ProfileController.new,
);

class ProfileController {
  ProfileController(this._ref);

  final Ref _ref;

  /// Enregistre le profil et met à jour la session affichée partout.
  Future<User> save(User updated) async {
    if (!AppConfig.useApiAuth) {
      final saved = await _ref.read(userRepositoryProvider).update(updated);
      _ref.read(authServiceProvider.notifier).updateUser(saved);
      return saved;
    }
    final token = _ref.read(authTokenProvider);
    final dio = _ref.read(dioProvider);
    final response = await dio.put<Map<String, dynamic>>(
      '/auth/me',
      data: {
        'firstName': updated.firstName,
        'lastName': updated.lastName,
        'email': updated.email,
        'phone': updated.phone,
        'avatarUrl': updated.avatarUrl,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final saved = User.fromJson(Map<String, dynamic>.from(response.data as Map));
    _ref.read(authServiceProvider.notifier).updateUser(saved);
    return saved;
  }
}
