import '../../models/rating_summary.dart';
import '../../models/review.dart';

/// Accès aux avis (implémenté par l'API Dio et par les données mock).
abstract interface class ReviewRepository {
  /// Avis publiés d'un restaurant (+ ceux de l'utilisateur, quel que soit leur statut).
  Future<List<Review>> fetchRestaurantReviews(String restaurantId);

  /// Moyenne et répartition des notes de tous les avis du restaurant.
  Future<RatingSummary> fetchSummary(String restaurantId);

  Future<List<Review>> fetchMyReviews();
  Future<Review> fetchReview(String reviewId);
  Future<Review> createReview(ReviewInput input);
  Future<Review> updateReview(String reviewId, ReviewInput input);
  Future<void> deleteReview(String reviewId);

  /// Marque / démarque un avis comme « utile ».
  Future<Review> toggleHelpful(String reviewId);
  Future<void> reportReview(String reviewId, String reason);

  /// Réponse publique du restaurant.
  Future<Review> replyToReview(String reviewId, String message);

  /// Modération (admin) : avis en attente, signalés ou refusés.
  Future<List<Review>> fetchModerationQueue();
  Future<Review> moderateReview(String reviewId, ReviewStatus status);
}
