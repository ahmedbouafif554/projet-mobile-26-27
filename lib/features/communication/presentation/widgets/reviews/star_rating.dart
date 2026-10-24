import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/theme_extensions.dart';

/// Libellé et emoji associés à une note de 1 à 5.
(String, String) ratingLabel(int rating) => switch (rating) {
  1 => ('😞', 'Très décevant'),
  2 => ('😕', 'Décevant'),
  3 => ('😐', 'Correct'),
  4 => ('😊', 'Très bien'),
  5 => ('🤩', 'Excellent !'),
  _ => ('⭐', 'Touchez une étoile'),
};

/// Affichage d'une note (avec demi-étoiles).
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final value = rating - i;
        return Icon(
          value >= 0.75
              ? Icons.star_rounded
              : value >= 0.25
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: value >= 0.25 ? color : context.palette.border,
        );
      }),
    );
  }
}

/// Saisie d'une note : on touche ou on fait glisser le doigt sur les étoiles,
/// qui rebondissent en vague à chaque changement.
class AnimatedStarRating extends StatelessWidget {
  const AnimatedStarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
    this.spacing = 8,
    this.semanticLabel = 'Note',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  final double spacing;
  final String semanticLabel;

  /// [step] : largeur d'une étoile et de son espacement, à l'échelle.
  void _select(double dx, double step) {
    final rating = (dx / step).floor().clamp(0, 4) + 1;
    if (rating != value) {
      HapticFeedback.selectionClick();
      onChanged(rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warning = context.palette.warning;

    // Réduit les étoiles si la place manque (petits écrans).
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = 5 * size + 4 * spacing;
        final scale = constraints.maxWidth < needed
            ? constraints.maxWidth / needed
            : 1.0;
        final starSize = size * scale;
        final gap = spacing * scale;
        final step = starSize + gap;

        return Semantics(
          label: '$semanticLabel : $value sur 5',
          slider: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _select(d.localPosition.dx, step),
            onHorizontalDragUpdate: (d) => _select(d.localPosition.dx, step),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < value;
                Widget star = Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: starSize,
                  color: filled ? warning : context.palette.border,
                );
                if (filled) {
                  // La clé dépend de la note : la vague est rejouée à chaque choix.
                  star = star
                      .animate(
                        key: ValueKey('star-$i-$value'),
                        delay: (45 * i).ms,
                      )
                      .scaleXY(
                        begin: 0.5,
                        end: 1,
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      )
                      .rotate(begin: -0.08, end: 0, duration: 300.ms);
                }
                return Padding(
                  padding: EdgeInsets.only(right: i < 4 ? gap : 0),
                  child: star,
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
