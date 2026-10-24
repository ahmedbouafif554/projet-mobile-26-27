import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/communication_repositories.dart';
import '../../data/reviews/review_repository.dart';
import '../../models/review.dart';

/// Onglets de la modération.
enum ModerationTab { pending, reported, rejected }

extension ModerationTabX on ModerationTab {
  String get label => switch (this) {
    ModerationTab.pending => 'En attente',
    ModerationTab.reported => 'Signalés',
    ModerationTab.rejected => 'Refusés',
  };

  bool matches(Review review) => switch (this) {
    ModerationTab.pending => review.status == ReviewStatus.pending,
    ModerationTab.reported =>
      review.status == ReviewStatus.approved && review.isReported,
    ModerationTab.rejected => review.status == ReviewStatus.rejected,
  };
}

/// File de modération des avis (espace administrateur).
class ReviewModerationController extends ChangeNotifier {
  ReviewModerationController({ReviewRepository? repository})
    : _repository = repository ?? CommunicationRepositories.reviews;

  /// Durée de l'animation de sortie d'une carte traitée.
  static const leaveDuration = Duration(milliseconds: 380);

  final ReviewRepository _repository;

  List<Review> _queue = [];
  final Set<String> _leaving = {};
  ModerationTab _tab = ModerationTab.pending;
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  ModerationTab get tab => _tab;
  bool get isLoading => _loading;
  String? get error => _error;
  bool isLeaving(Review review) => _leaving.contains(review.id);

  List<Review> get visible => _queue.where(_tab.matches).toList();
  int countOf(ModerationTab tab) => _queue.where(tab.matches).length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _queue = await _repository.fetchModerationQueue();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void selectTab(ModerationTab tab) {
    _tab = tab;
    _notify();
  }

  /// Approuve ou refuse un avis ; la carte sort de la liste en glissant.
  Future<String?> moderate(Review review, ReviewStatus status) async {
    try {
      final updated = await _repository.moderateReview(review.id, status);
      _leaving.add(review.id);
      _notify();
      await Future<void>.delayed(leaveDuration);
      _leaving.remove(review.id);
      _queue = [for (final r in _queue) r.id == review.id ? updated : r];
      _notify();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Répond au nom du restaurant.
  Future<String?> reply(Review review, String message) async {
    try {
      final updated = await _repository.replyToReview(review.id, message);
      _queue = [for (final r in _queue) r.id == review.id ? updated : r];
      _notify();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
