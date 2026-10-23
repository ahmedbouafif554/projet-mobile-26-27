import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pressable.dart';
import '../../models/promotion.dart';

/// Carrousel de promotions : défilement automatique, effet de profondeur
/// sur les cartes voisines et indicateur animé.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({
    super.key,
    required this.promotions,
    required this.onTap,
  });

  final List<Promotion> promotions;
  final ValueChanged<Promotion> onTap;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _autoPlay;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartAutoPlay();
  }

  /// Relance le minuteur (appelé aussi quand l'utilisateur fait défiler).
  void _restartAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % widget.promotions.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.promotions.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _restartAutoPlay();
            },
            itemBuilder: (context, i) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Les cartes voisines sont légèrement réduites.
                  var scale = i == _page ? 1.0 : 0.92;
                  if (_controller.hasClients &&
                      _controller.position.haveDimensions) {
                    final delta = ((_controller.page ?? 0) - i).abs();
                    scale = (1 - delta * 0.08).clamp(0.92, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: _PromoCard(
                  promotion: widget.promotions[i],
                  onTap: () => widget.onTap(widget.promotions[i]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.promotions.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: AppDurations.medium,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : context.palette.border,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promotion, required this.onTap});

  final Promotion promotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: promotion.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        child: Stack(
          children: [
            // Cercles décoratifs
            Positioned(
              right: -40,
              top: -50,
              child: _circle(170, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              left: -30,
              bottom: -60,
              child: _circle(120, Colors.white.withValues(alpha: 0.07)),
            ),
            // Photo ronde à droite
            Positioned(
              right: -18,
              bottom: -18,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: AppNetworkImage(
                    promotion.imageUrl,
                    width: 128,
                    height: 128,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg - 4),
              child: FractionallySizedBox(
                widthFactor: 0.64,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Offre limitée',
                        style: context.text.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      promotion.title,
                      maxLines: 2,
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promotion.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
