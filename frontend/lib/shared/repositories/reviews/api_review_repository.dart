import '../../models/review.dart';
import '../base/api_crud_repository.dart';
import 'review_repository.dart';

class ApiReviewRepository extends ApiCrudRepository<Review>
    implements ReviewRepository {
  ApiReviewRepository(super.dio) : super(path: '/reviews');

  @override
  Review fromJson(Map<String, dynamic> json) => Review.fromJson(json);

  @override
  Map<String, dynamic> toJson(Review item) => item.toJson();

  @override
  String idOf(Review item) => item.id;

  @override
  Future<List<Review>> forRestaurant(
    String restaurantId, {
    bool onlyPublished = false,
  }) => getList(
    '/restaurants/$restaurantId/reviews',
    query: {if (onlyPublished) 'status': ReviewStatus.approved.name},
  );

  @override
  Future<Review> moderate(String id, ReviewStatus status) =>
      patch(id, 'status', {'status': status.name});

  @override
  Future<Review> reply(String id, ReviewReply reply) =>
      patch(id, 'reply', reply.toJson());
}
