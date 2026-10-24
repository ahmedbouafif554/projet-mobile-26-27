import '../../models/review.dart';
import '../base/crud_repository.dart';

/// Avis clients (Module 5).
abstract interface class ReviewRepository implements CrudRepository<Review> {
  /// Avis d'un restaurant ; [onlyPublished] pour le front office.
  Future<List<Review>> forRestaurant(
    String restaurantId, {
    bool onlyPublished = false,
  });

  /// Approuver / refuser un avis (modération).
  Future<Review> moderate(String id, ReviewStatus status);

  /// Réponse publique du restaurant ou de l'admin.
  Future<Review> reply(String id, ReviewReply reply);
}
