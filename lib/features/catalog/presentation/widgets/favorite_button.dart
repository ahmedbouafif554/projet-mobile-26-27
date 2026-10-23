import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pressable.dart';
import '../controllers/favorites_controller.dart';

/// Bouton cœur : au passage en favori, le cœur grossit puis se pose,
/// et une onde se propage autour de lui.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.restaurantId,
    this.size = 40,
    this.elevated = true,
  });

  final String restaurantId;
  final double size;
  final bool elevated;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Séquence : grossit -> se contracte -> revient à la normale.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.45,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.45,
        end: 0.88,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.88,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final added = FavoritesController.instance.toggle(widget.restaurantId);
    HapticFeedback.lightImpact();
    if (added) _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return ListenableBuilder(
      listenable: FavoritesController.instance,
      builder: (context, _) {
        final isFavorite = FavoritesController.instance.isFavorite(
          widget.restaurantId,
        );

        return Semantics(
          button: true,
          label: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          child: Pressable(
            onTap: _toggle,
            scale: 0.85,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      shape: BoxShape.circle,
                      border: widget.elevated
                          ? null
                          : Border.all(color: context.palette.border),
                      boxShadow: widget.elevated
                          ? context.palette.softShadow
                          : null,
                    ),
                  ),
                  // Onde qui s'étend et disparaît
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      if (t == 0 || t == 1) return const SizedBox.shrink();
                      return IgnorePointer(
                        child: Container(
                          width: size * (0.6 + t * 0.9),
                          height: size * (0.6 + t * 0.9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.favorite.withValues(
                                alpha: 1 - t,
                              ),
                              width: 2.5 * (1 - t) + 0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ScaleTransition(
                    scale: _scale,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(isFavorite),
                        color: isFavorite
                            ? AppColors.favorite
                            : context.colors.onSurface,
                        size: size * 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
