import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/repositories/repository_providers.dart';
import '../domain/gift_order.dart';
import '../domain/livreur_tip.dart';

/// Récupère le cadeau rattaché à une commande.
final orderGiftProvider =
    FutureProvider.family<GiftOrder?, String>((ref, orderId) async {
      final repo = ref.watch(orderRepositoryProvider);
      try {
        final data = await repo.getGift(orderId);
        if (data.isEmpty) return null;
        return GiftOrder.fromJson(data);
      } catch (_) {
        return null;
      }
    });

/// Révélation d'un cadeau via QR code token.
final revealGiftProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, qrToken) async {
      final repo = ref.watch(orderRepositoryProvider);
      return await repo.revealGift(qrToken);
    });

/// Récupère les pourboires enregistrés pour une commande.
final orderTipProvider =
    FutureProvider.family<List<LivreurTip>, String>((ref, orderId) async {
      final repo = ref.watch(orderRepositoryProvider);
      try {
        final res = await repo.getTip(orderId);
        final list = (res['tips'] as List?) ?? [];
        return list
            .map((e) => LivreurTip.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        return [];
      }
    });

/// Historique des pourboires d'un coursier.
final courierTipHistoryProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, courierId) async {
      final repo = ref.watch(orderRepositoryProvider);
      return await repo.getCourierTips(courierId);
    });

/// Contrôleur d'actions pour les pourboires.
final tipActionProvider = Provider((ref) {
  final repo = ref.watch(orderRepositoryProvider);
  return TipActionService(repo, ref);
});

class TipActionService {
  TipActionService(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<LivreurTip> sendTip({
    required String orderId,
    required double amount,
    double? percentage,
    String? thankYouMessage,
    String paymentMethod = 'card',
  }) async {
    final res = await _repo.addTip(orderId, {
      'amount': amount,
      if (percentage != null) 'percentage': percentage,
      if (thankYouMessage != null && thankYouMessage.isNotEmpty)
        'thankYouMessage': thankYouMessage,
      'paymentMethod': paymentMethod,
    });
    // Invalidate tip provider for that order
    _ref.invalidate(orderTipProvider(orderId));
    return LivreurTip.fromJson(Map<String, dynamic>.from(res as Map));
  }
}

