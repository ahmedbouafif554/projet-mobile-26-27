import 'review.dart';

/// Résumé des notes d'un restaurant (moyenne, répartition, critères).
class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.distribution,
    required this.criteria,
  });

  final double average;
  final int count;

  /// Nombre d'avis par nombre d'étoiles (1 à 5).
  final Map<int, int> distribution;

  /// Moyenne de chaque critère.
  final Map<ReviewCriterion, double> criteria;

  static const empty = RatingSummary(
    average: 0,
    count: 0,
    distribution: {},
    criteria: {},
  );

  /// Part (0 à 1) des avis ayant [stars] étoiles.
  double ratioOf(int stars) =>
      count == 0 ? 0 : (distribution[stars] ?? 0) / count;

  /// Calcule le résumé à partir d'une liste d'avis.
  factory RatingSummary.fromReviews(List<Review> reviews) {
    if (reviews.isEmpty) return empty;
    final distribution = {for (var s = 1; s <= 5; s++) s: 0};
    for (final r in reviews) {
      distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
    }
    double avgOf(ReviewCriterion c) {
      final values = reviews
          .map((r) => r.criteria[c])
          .whereType<int>()
          .toList();
      return values.isEmpty
          ? 0
          : values.reduce((a, b) => a + b) / values.length;
    }

    return RatingSummary(
      average:
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length,
      count: reviews.length,
      distribution: distribution,
      criteria: {for (final c in ReviewCriterion.values) c: avgOf(c)},
    );
  }

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final dist = (json['distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    final crit = (json['criteria'] as Map?)?.cast<String, dynamic>() ?? {};
    return RatingSummary(
      average: (json['average'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      distribution: {
        for (final e in dist.entries)
          int.parse(e.key): (e.value as num).toInt(),
      },
      criteria: {
        for (final c in ReviewCriterion.values)
          if (crit[c.name] != null) c: (crit[c.name] as num).toDouble(),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'average': average,
    'count': count,
    'distribution': {for (final e in distribution.entries) '${e.key}': e.value},
    'criteria': {for (final e in criteria.entries) e.key.name: e.value},
  };
}
