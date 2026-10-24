import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../shared/models/address.dart';
import '../../../../shared/repositories/repository_providers.dart';

/// Adresses de l'utilisateur connecté (CRUD) : l'adresse par défaut en
/// premier.
final addressesProvider =
    AsyncNotifierProvider<AddressesController, List<Address>>(
      AddressesController.new,
    );

class AddressesController extends AsyncNotifier<List<Address>> {
  String get _userId => ref.read(authServiceProvider).user!.id;

  @override
  Future<List<Address>> build() async {
    final userId = ref.watch(authServiceProvider).user?.id;
    if (userId == null) return const [];
    return _sorted(await ref.watch(addressRepositoryProvider).forUser(userId));
  }

  static List<Address> _sorted(List<Address> addresses) => [
    ...addresses.where((a) => a.isDefault),
    ...addresses.where((a) => !a.isDefault),
  ];

  /// Crée ([Address.id] vide) ou modifie une adresse. La première adresse,
  /// ou une adresse cochée « par défaut », devient l'adresse par défaut.
  Future<void> save(Address address) async {
    final repository = ref.read(addressRepositoryProvider);
    final isFirst = (state.value ?? const []).isEmpty;
    final saved = address.id.isEmpty
        ? await repository.create(address.copyWith(userId: _userId))
        : await repository.update(address);
    if (isFirst || saved.isDefault) {
      await repository.setDefault(_userId, saved.id);
    }
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(Address address) async {
    final repository = ref.read(addressRepositoryProvider);
    await repository.delete(address.id);
    // L'adresse par défaut supprimée : la suivante prend le relais.
    final rest = (state.value ?? const []).where((a) => a.id != address.id);
    if (address.isDefault && rest.isNotEmpty) {
      await repository.setDefault(_userId, rest.first.id);
    }
    ref.invalidateSelf();
    await future;
  }

  Future<void> setDefault(Address address) async {
    final updated = await ref
        .read(addressRepositoryProvider)
        .setDefault(_userId, address.id);
    state = AsyncData(_sorted(updated));
  }
}
