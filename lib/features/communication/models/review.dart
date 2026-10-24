import 'json_utils.dart';

/// Critères notés séparément dans un avis.
enum ReviewCriterion { food, delivery, packaging }

extension ReviewCriterionX on ReviewCriterion {
  String get label => switch (this) {
    ReviewCriterion.food => 'Nourriture',
    ReviewCriterion.delivery => 'Livraison',
    ReviewCriterion.packaging => 'Emballage',
  };
}

/// Statut de modération d'un avis.
enum ReviewStatus { pending, approved, rejected }

extension ReviewStatusX on ReviewStatus {
  String get label => switch (this) {
    ReviewStatus.pending => 'En attente de validation',
    ReviewStatus.approved => 'Publié',
    ReviewStatus.rejected => 'Refusé par la modération',
  };
}

/// Réponse publique du restaurant à un avis.
class ReviewReply {
  const ReviewReply({
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  final String authorName;
  final String message;
  final DateTime createdAt;

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
    authorName: json['author_name'] as String? ?? '',
    message: json['message'] as String? ?? '',
    createdAt: parseDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'author_name': authorName,
    'message': message,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

/// Avis laissé par un client sur un restaurant.
class Review {
  const Review({
    required this.id,
    required this.restaurantId,
    required this.authorId,
    required this.authorName,
    required this.rating,
    required this.criteria,
    required this.comment,
    required this.createdAt,
    this.authorAvatarUrl,
    this.orderId,
    this.photos = const [],
    this.updatedAt,
    this.reply,
    this.status = ReviewStatus.approved,
    this.helpfulCount = 0,
    this.isHelpfulByMe = false,
    this.reportCount = 0,
  });

  final String id;
  final String restaurantId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String? orderId;

  /// Note globale de 1 à 5.
  final int rating;

  /// Notes détaillées (nourriture, livraison, emballage).
  final Map<ReviewCriterion, int> criteria;
  final String comment;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ReviewReply? reply;
  final ReviewStatus status;
  final int helpfulCount;
  final bool isHelpfulByMe;

  /// Nombre de signalements par d'autres utilisateurs.
  final int reportCount;

  bool isMine(String userId) => authorId == userId;
  bool get hasPhotos => photos.isNotEmpty;
  bool get isEdited => updatedAt != null;
  bool get isReported => reportCount > 0;

  Review copyWith({
    int? rating,
    Map<ReviewCriterion, int>? criteria,
    String? comment,
    List<String>? photos,
    DateTime? updatedAt,
    ReviewReply? reply,
    ReviewStatus? status,
    int? helpfulCount,
    bool? isHelpfulByMe,
    int? reportCount,
  }) {
    return Review(
      id: id,
      restaurantId: restaurantId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      orderId: orderId,
      rating: rating ?? this.rating,
      criteria: criteria ?? this.criteria,
      comment: comment ?? this.comment,
      photos: photos ?? this.photos,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reply: reply ?? this.reply,
      status: status ?? this.status,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isHelpfulByMe: isHelpfulByMe ?? this.isHelpfulByMe,
      reportCount: reportCount ?? this.reportCount,
    );
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    final criteriaJson =
        (json['criteria'] as Map?)?.cast<String, dynamic>() ?? {};
    return Review(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Client',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      orderId: json['order_id'] as String?,
      rating: (json['rating'] as num).toInt(),
      criteria: {
        for (final c in ReviewCriterion.values)
          if (criteriaJson[c.name] != null)
            c: (criteriaJson[c.name] as num).toInt(),
      },
      comment: json['comment'] as String? ?? '',
      photos: (json['photos'] as List?)?.cast<String>() ?? const [],
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDateOrNull(json['updated_at']),
      reply: json['reply'] == null
          ? null
          : ReviewReply.fromJson(json['reply'] as Map<String, dynamic>),
      status: enumFromJson(
        ReviewStatus.values,
        json['status'],
        ReviewStatus.approved,
      ),
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      isHelpfulByMe: json['is_helpful_by_me'] as bool? ?? false,
      reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'author_id': authorId,
    'author_name': authorName,
    'author_avatar_url': authorAvatarUrl,
    'order_id': orderId,
    'rating': rating,
    'criteria': {for (final e in criteria.entries) e.key.name: e.value},
    'comment': comment,
    'photos': photos,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
    'reply': reply?.toJson(),
    'status': status.name,
    'helpful_count': helpfulCount,
    'is_helpful_by_me': isHelpfulByMe,
    'report_count': reportCount,
  };
}

/// Données saisies dans le formulaire (création ou modification d'un avis).
class ReviewInput {
  const ReviewInput({
    required this.restaurantId,
    required this.rating,
    required this.criteria,
    required this.comment,
    this.orderId,
    this.photos = const [],
  });

  final String restaurantId;
  final String? orderId;
  final int rating;
  final Map<ReviewCriterion, int> criteria;
  final String comment;
  final List<String> photos;

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'order_id': orderId,
    'rating': rating,
    'criteria': {for (final e in criteria.entries) e.key.name: e.value},
    'comment': comment,
    'photos': photos,
  };
}
