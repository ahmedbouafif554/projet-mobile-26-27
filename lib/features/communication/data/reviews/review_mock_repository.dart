import 'dart:async';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../catalog/data/catalog_mock_data.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../communication_routes.dart';
import '../../models/app_notification.dart';
import '../../models/rating_summary.dart';
import '../../models/review.dart';
import '../mock/communication_mock_data.dart';
import '../notifications/notification_mock_repository.dart';
import 'review_repository.dart';

/// Avis simulés en mémoire, avec latence et réactions « serveur » :
/// après publication, l'avis est validé et le restaurant répond.
class ReviewMockRepository implements ReviewRepository {
  ReviewMockRepository({this.notifications});

  /// Permet de simuler la notification push « le restaurant a répondu ».
  final NotificationMockRepository? notifications;

  late final List<Review> _reviews = CommunicationMockData.reviewsJson()
      .map(Review.fromJson)
      .toList();
  int _sequence = 0;

  String get _me => AppConfig.currentUserId;

  Future<T> _respond<T>(T Function() compute) async {
    await Future<void>.delayed(AppConfig.mockLatency);
    return compute();
  }

  Review _find(String id) => _reviews.firstWhere(
    (r) => r.id == id,
    orElse: () =>
        throw const ApiException('Avis introuvable.', statusCode: 404),
  );

  Review _save(Review review) {
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index >= 0) _reviews[index] = review;
    return review;
  }

  List<Review> _sorted(Iterable<Review> reviews) =>
      reviews.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Review>> fetchRestaurantReviews(String restaurantId) => _respond(
    () => _sorted(
      _reviews.where(
        (r) =>
            r.restaurantId == restaurantId &&
            (r.status == ReviewStatus.approved || r.isMine(_me)),
      ),
    ),
  );

  @override
  Future<RatingSummary> fetchSummary(String restaurantId) => _respond(() {
    // Le catalogue donne la note et le nombre d'avis « historiques » ;
    // on y ajoute les avis publiés pendant la session.
    final restaurant = CatalogMockData.restaurantById(restaurantId);
    final shares = restaurant.rating >= 4.7
        ? [0.80, 0.14, 0.03, 0.02, 0.01]
        : restaurant.rating >= 4.5
        ? [0.68, 0.22, 0.06, 0.02, 0.02]
        : [0.55, 0.28, 0.10, 0.04, 0.03];
    var count = restaurant.reviewCount;
    var total = restaurant.rating * count;
    final distribution = {
      for (var i = 0; i < 5; i++) 5 - i: (shares[i] * count).round(),
    };
    final criteriaTotals = {
      ReviewCriterion.food: (restaurant.rating + 0.1).clamp(0, 5) * count,
      ReviewCriterion.delivery: (restaurant.rating - 0.2) * count,
      ReviewCriterion.packaging: (restaurant.rating - 0.05) * count,
    };

    for (final r in _reviews.where(
      (r) => r.restaurantId == restaurantId && r.id.startsWith('rev-new-'),
    )) {
      count++;
      total += r.rating;
      distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
      for (final c in ReviewCriterion.values) {
        criteriaTotals[c] = criteriaTotals[c]! + (r.criteria[c] ?? r.rating);
      }
    }

    return RatingSummary(
      average: total / count,
      count: count,
      distribution: distribution,
      criteria: {
        for (final e in criteriaTotals.entries) e.key: e.value / count,
      },
    );
  });

  @override
  Future<List<Review>> fetchMyReviews() =>
      _respond(() => _sorted(_reviews.where((r) => r.isMine(_me))));

  @override
  Future<Review> fetchReview(String reviewId) =>
      _respond(() => _find(reviewId));

  @override
  Future<Review> createReview(ReviewInput input) => _respond(() {
    final user = ProfileController.instance.user;
    final review = Review(
      id: 'rev-new-${++_sequence}',
      restaurantId: input.restaurantId,
      orderId: input.orderId,
      authorId: _me,
      authorName: '${user.firstName} ${user.lastName.substring(0, 1)}.',
      authorAvatarUrl: user.avatarUrl,
      rating: input.rating,
      criteria: input.criteria,
      comment: input.comment,
      photos: input.photos,
      createdAt: DateTime.now(),
      status: ReviewStatus.pending,
    );
    _reviews.insert(0, review);
    _simulateModerationAndReply(review.id);
    return review;
  });

  /// Simule le serveur : validation par la modération puis réponse du restaurant.
  void _simulateModerationAndReply(String reviewId) {
    Timer(AppConfig.mockServerDelay, () {
      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index < 0) return; // supprimé entre-temps
      final review = _reviews[index];
      final restaurant = CatalogMockData.restaurantById(review.restaurantId);
      final message = review.rating >= 4
          ? 'Merci pour votre note de ${review.rating}/5 ! À très vite 😊'
          : 'Merci pour votre retour, nous allons nous améliorer.';
      _reviews[index] = review.copyWith(
        status: ReviewStatus.approved,
        reply: ReviewReply(
          authorName: restaurant.name,
          message: message,
          createdAt: DateTime.now(),
        ),
      );
      notifications?.simulateIncoming(
        AppNotification(
          id: 'push-review-$reviewId',
          type: NotificationType.review,
          title: '${restaurant.name} a répondu à votre avis',
          body: '« $message »',
          createdAt: DateTime.now(),
          route: CommunicationRoutes.myReviews,
        ),
      );
    });
  }

  @override
  Future<Review> updateReview(String reviewId, ReviewInput input) => _respond(
    () => _save(
      _find(reviewId).copyWith(
        rating: input.rating,
        criteria: input.criteria,
        comment: input.comment,
        photos: input.photos,
        updatedAt: DateTime.now(),
      ),
    ),
  );

  @override
  Future<void> deleteReview(String reviewId) =>
      _respond(() => _reviews.removeWhere((r) => r.id == reviewId));

  @override
  Future<Review> toggleHelpful(String reviewId) => _respond(() {
    final review = _find(reviewId);
    final helpful = !review.isHelpfulByMe;
    return _save(
      review.copyWith(
        isHelpfulByMe: helpful,
        helpfulCount: review.helpfulCount + (helpful ? 1 : -1),
      ),
    );
  });

  @override
  Future<void> reportReview(String reviewId, String reason) => _respond(() {
    final review = _find(reviewId);
    _save(review.copyWith(reportCount: review.reportCount + 1));
  });

  @override
  Future<Review> replyToReview(String reviewId, String message) => _respond(() {
    final review = _find(reviewId);
    return _save(
      review.copyWith(
        reply: ReviewReply(
          authorName: CatalogMockData.restaurantById(review.restaurantId).name,
          message: message,
          createdAt: DateTime.now(),
        ),
      ),
    );
  });

  @override
  Future<List<Review>> fetchModerationQueue() => _respond(
    () => _sorted(
      _reviews.where((r) => r.status != ReviewStatus.approved || r.isReported),
    ),
  );

  @override
  Future<Review> moderateReview(String reviewId, ReviewStatus status) =>
      _respond(
        () => _save(
          _find(reviewId).copyWith(
            status: status,
            // Approuver un avis signalé revient à ignorer les signalements.
            reportCount: status == ReviewStatus.approved ? 0 : null,
          ),
        ),
      );
}
