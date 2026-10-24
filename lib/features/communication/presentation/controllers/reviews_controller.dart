import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/communication_repositories.dart';
import '../../data/reviews/review_repository.dart';
import '../../models/rating_summary.dart';
import '../../models/review.dart';

/// Tri de la liste des avis.
enum ReviewSort { recent, best, worst }

extension ReviewSortX on ReviewSort {
  String get label => switch (this) {
    ReviewSort.recent => 'Plus récents',
    ReviewSort.best => 'Meilleures notes',
    ReviewSort.worst => 'Moins bonnes notes',
  };
}

/// Liste d'avis filtrable : ceux d'un restaurant (avec résumé des notes)
/// ou ceux de l'utilisateur (« Mes avis »).
class ReviewsController extends ChangeNotifier {
  /// Avis d'un restaurant.
  ReviewsController.restaurant(
    String this.restaurantId, {
    ReviewRepository? repository,
  }) : _repository = repository ?? CommunicationRepositories.reviews;

  /// Avis de l'utilisateur connecté.
  ReviewsController.mine({ReviewRepository? repository})
    : restaurantId = null,
      _repository = repository ?? CommunicationRepositories.reviews;

  final String? restaurantId;
  final ReviewRepository _repository;

  List<Review> _all = [];
  RatingSummary _summary = RatingSummary.empty;
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  int? _starFilter;
  bool _withPhotos = false;
  bool _withReply = false;
  ReviewSort _sort = ReviewSort.recent;

  RatingSummary get summary => _summary;
  bool get isLoading => _loading;
  String? get error => _error;
  int? get starFilter => _starFilter;
  bool get withPhotos => _withPhotos;
  bool get withReply => _withReply;
  ReviewSort get sort => _sort;
  bool get hasFilters => _starFilter != null || _withPhotos || _withReply;
  String get me => AppConfig.currentUserId;

  /// Avis après filtres et tri.
  List<Review> get visible {
    final list = _all.where((r) {
      if (_starFilter != null && r.rating != _starFilter) return false;
      if (_withPhotos && !r.hasPhotos) return false;
      if (_withReply && r.reply == null) return false;
      return true;
    }).toList();
    switch (_sort) {
      case ReviewSort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ReviewSort.best:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case ReviewSort.worst:
        list.sort((a, b) => a.rating.compareTo(b.rating));
    }
    return list;
  }

  /// Signature des filtres (sert de clé pour rejouer les animations).
  String get filterKey => '$_starFilter-$_withPhotos-$_withReply-${_sort.name}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final id = restaurantId;
      if (id == null) {
        _all = await _repository.fetchMyReviews();
      } else {
        final reviews = _repository.fetchRestaurantReviews(id);
        final summary = _repository.fetchSummary(id);
        _all = await reviews;
        _summary = await summary;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setStarFilter(int? stars) {
    _starFilter = _starFilter == stars ? null : stars;
    _notify();
  }

  void toggleWithPhotos() {
    _withPhotos = !_withPhotos;
    _notify();
  }

  void toggleWithReply() {
    _withReply = !_withReply;
    _notify();
  }

  void setSort(ReviewSort sort) {
    _sort = sort;
    _notify();
  }

  void clearFilters() {
    _starFilter = null;
    _withPhotos = false;
    _withReply = false;
    _notify();
  }

  void _replace(Review review) {
    _all = [for (final r in _all) r.id == review.id ? review : r];
    _notify();
  }

  Future<String?> toggleHelpful(Review review) async {
    // Mise à jour optimiste pour une réaction instantanée du bouton.
    final helpful = !review.isHelpfulByMe;
    _replace(
      review.copyWith(
        isHelpfulByMe: helpful,
        helpfulCount: review.helpfulCount + (helpful ? 1 : -1),
      ),
    );
    try {
      _replace(await _repository.toggleHelpful(review.id));
      return null;
    } on ApiException catch (e) {
      _replace(review);
      return e.message;
    }
  }

  Future<String?> report(Review review, String reason) async {
    try {
      await _repository.reportReview(review.id, reason);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> delete(Review review) async {
    final previous = _all;
    _all = _all.where((r) => r.id != review.id).toList();
    _notify();
    try {
      await _repository.deleteReview(review.id);
      final id = restaurantId;
      if (id != null) {
        _summary = await _repository.fetchSummary(id);
        _notify();
      }
      return null;
    } on ApiException catch (e) {
      _all = previous;
      _notify();
      return e.message;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
