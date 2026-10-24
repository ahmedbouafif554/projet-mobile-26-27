import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../models/rating_summary.dart';
import '../../models/review.dart';
import 'review_repository.dart';

/// Avis via l'API REST.
class ReviewApiRepository implements ReviewRepository {
  ReviewApiRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Review>> fetchRestaurantReviews(String restaurantId) =>
      runApi(() async {
        final response = await _dio.get('/restaurants/$restaurantId/reviews');
        return jsonList(response.data).map(Review.fromJson).toList();
      });

  @override
  Future<RatingSummary> fetchSummary(String restaurantId) => runApi(() async {
    final response = await _dio.get(
      '/restaurants/$restaurantId/reviews/summary',
    );
    return RatingSummary.fromJson(jsonMap(response.data));
  });

  @override
  Future<List<Review>> fetchMyReviews() => runApi(() async {
    final response = await _dio.get('/me/reviews');
    return jsonList(response.data).map(Review.fromJson).toList();
  });

  @override
  Future<Review> fetchReview(String reviewId) => runApi(() async {
    final response = await _dio.get('/reviews/$reviewId');
    return Review.fromJson(jsonMap(response.data));
  });

  @override
  Future<Review> createReview(ReviewInput input) => runApi(() async {
    final response = await _dio.post('/reviews', data: input.toJson());
    return Review.fromJson(jsonMap(response.data));
  });

  @override
  Future<Review> updateReview(String reviewId, ReviewInput input) =>
      runApi(() async {
        final response = await _dio.put(
          '/reviews/$reviewId',
          data: input.toJson(),
        );
        return Review.fromJson(jsonMap(response.data));
      });

  @override
  Future<void> deleteReview(String reviewId) =>
      runApi(() => _dio.delete<void>('/reviews/$reviewId'));

  @override
  Future<Review> toggleHelpful(String reviewId) => runApi(() async {
    final response = await _dio.post('/reviews/$reviewId/helpful');
    return Review.fromJson(jsonMap(response.data));
  });

  @override
  Future<void> reportReview(String reviewId, String reason) => runApi(
    () =>
        _dio.post<void>('/reviews/$reviewId/reports', data: {'reason': reason}),
  );

  @override
  Future<Review> replyToReview(String reviewId, String message) =>
      runApi(() async {
        final response = await _dio.post(
          '/reviews/$reviewId/reply',
          data: {'message': message},
        );
        return Review.fromJson(jsonMap(response.data));
      });

  @override
  Future<List<Review>> fetchModerationQueue() => runApi(() async {
    final response = await _dio.get(
      '/admin/reviews',
      queryParameters: {'status': 'moderation'},
    );
    return jsonList(response.data).map(Review.fromJson).toList();
  });

  @override
  Future<Review> moderateReview(String reviewId, ReviewStatus status) =>
      runApi(() async {
        final response = await _dio.patch(
          '/admin/reviews/$reviewId',
          data: {'status': status.name},
        );
        return Review.fromJson(jsonMap(response.data));
      });
}
