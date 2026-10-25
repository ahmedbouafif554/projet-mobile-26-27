import '../../models/review.dart';
import '../base/mock_crud_repository.dart';
import 'review_repository.dart';

class MockReviewRepository extends MockCrudRepository<Review>
    implements ReviewRepository {
  MockReviewRepository(super.seed) : super(idPrefix: 'rev');

  @override
  String idOf(Review item) => item.id;

  @override
  Review withId(Review item, String id) => item.copyWith(id: id);

  @override
  Future<List<Review>> getAll() async =>
      (await super.getAll())
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Review>> forRestaurant(
    String restaurantId, {
    bool onlyPublished = false,
  }) async => (await where(
    (r) =>
        r.restaurantId == restaurantId &&
        (!onlyPublished || r.status == ReviewStatus.approved),
  ))..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Review> moderate(String id, ReviewStatus status) =>
      mutate(id, (r) => r.copyWith(status: status));

  @override
  Future<Review> reply(String id, ReviewReply reply) =>
      mutate(id, (r) => r.copyWith(reply: reply));
}
