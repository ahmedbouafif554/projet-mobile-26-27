import 'json_utils.dart';

enum ReviewStatus {
  pending('En attente'),
  approved('Publié'),
  rejected('Refusé');

  const ReviewStatus(this.label);
  final String label;
}

/// Réponse publique du restaurant (ou de l'admin) à un avis.
class ReviewReply {
  const ReviewReply({
    required this.text,
    required this.authorName,
    required this.at,
  });

  final String text;
  final String authorName;
  final DateTime at;

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
    text: json['text'] as String,
    authorName: json['authorName'] as String? ?? '',
    at: parseDate(json['at']),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'authorName': authorName,
    'at': at.toIso8601String(),
  };
}

/// Avis d'un client sur un restaurant (note globale et par critère).
class Review {
  const Review({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.orderId,
    required this.rating,
    this.foodRating,
    this.deliveryRating,
    this.packagingRating,
    this.comment = '',
    this.photos = const [],
    this.status = ReviewStatus.pending,
    this.reply,
    this.helpfulCount = 0,
    this.reportCount = 0,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? orderId;

  /// Note globale de 1 à 5.
  final int rating;
  final int? foodRating;
  final int? deliveryRating;
  final int? packagingRating;
  final String comment;
  final List<String> photos;
  final ReviewStatus status;
  final ReviewReply? reply;
  final int helpfulCount;

  /// Signalements reçus (priorité de modération).
  final int reportCount;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    restaurantId: json['restaurantId'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String? ?? '',
    userAvatar: json['userAvatar'] as String?,
    orderId: json['orderId'] as String?,
    rating: parseInt(json['rating'], 5),
    foodRating: (json['foodRating'] as num?)?.toInt(),
    deliveryRating: (json['deliveryRating'] as num?)?.toInt(),
    packagingRating: (json['packagingRating'] as num?)?.toInt(),
    comment: json['comment'] as String? ?? '',
    photos: parseStrings(json['photos']),
    status: parseEnum(
      ReviewStatus.values,
      json['status'],
      ReviewStatus.pending,
    ),
    reply: json['reply'] == null
        ? null
        : ReviewReply.fromJson(json['reply'] as Map<String, dynamic>),
    helpfulCount: parseInt(json['helpfulCount']),
    reportCount: parseInt(json['reportCount']),
    createdAt: parseDate(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurantId': restaurantId,
    'userId': userId,
    'userName': userName,
    'userAvatar': userAvatar,
    'orderId': orderId,
    'rating': rating,
    'foodRating': foodRating,
    'deliveryRating': deliveryRating,
    'packagingRating': packagingRating,
    'comment': comment,
    'photos': photos,
    'status': status.name,
    'reply': reply?.toJson(),
    'helpfulCount': helpfulCount,
    'reportCount': reportCount,
    'createdAt': createdAt.toIso8601String(),
  };

  Review copyWith({
    String? id,
    String? restaurantId,
    String? userId,
    String? userName,
    Object? userAvatar = keep,
    Object? orderId = keep,
    int? rating,
    Object? foodRating = keep,
    Object? deliveryRating = keep,
    Object? packagingRating = keep,
    String? comment,
    List<String>? photos,
    ReviewStatus? status,
    Object? reply = keep,
    int? helpfulCount,
    int? reportCount,
    DateTime? createdAt,
  }) => Review(
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    userAvatar: userAvatar == keep ? this.userAvatar : userAvatar as String?,
    orderId: orderId == keep ? this.orderId : orderId as String?,
    rating: rating ?? this.rating,
    foodRating: foodRating == keep ? this.foodRating : foodRating as int?,
    deliveryRating: deliveryRating == keep
        ? this.deliveryRating
        : deliveryRating as int?,
    packagingRating: packagingRating == keep
        ? this.packagingRating
        : packagingRating as int?,
    comment: comment ?? this.comment,
    photos: photos ?? this.photos,
    status: status ?? this.status,
    reply: reply == keep ? this.reply : reply as ReviewReply?,
    helpfulCount: helpfulCount ?? this.helpfulCount,
    reportCount: reportCount ?? this.reportCount,
    createdAt: createdAt ?? this.createdAt,
  );
}
