import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../data/delivery_mock_data.dart';

/// Carte simulée (aucun SDK de cartographie) : quartiers dessinés,
/// itinéraire, restaurant, domicile et livreur animé le long du trajet.
class FakeMap extends StatelessWidget {
  const FakeMap({
    super.key,
    required this.progress,
    required this.pulse,
    this.originIcon = Icons.storefront_rounded,
  });

  /// Avancement du livreur sur le trajet (0 = départ, 1 = arrivée).
  final Animation<double> progress;

  /// Animation en boucle pour les halos (0 -> 1).
  final Animation<double> pulse;
  final IconData originIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Le panneau du bas couvre ~50 % de l'écran : la grille est
        // dimensionnée pour que tout le trajet reste dans la moitié haute.
        final cell = math.min(size.width / 4, size.height * 0.5 / 4.1);
        final origin = Offset((size.width - cell * 4) / 2, 0);
        final points = [
          for (final p in DeliveryMockData.route) origin + p * cell,
        ];
        final route = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          route.lineTo(p.dx, p.dy);
        }
        final metric = route.computeMetrics().first;

        return Stack(
          children: [
            // Fond statique : dessiné une seule fois.
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CityPainter(
                    cell: cell,
                    origin: origin,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([progress, pulse]),
              builder: (context, _) {
                final t = progress.value.clamp(0.0, 1.0);
                final courier = metric
                    .getTangentForOffset(metric.length * t)!
                    .position;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RoutePainter(metric: metric, progress: t),
                      ),
                    ),
                    _Marker(
                      position: points.first,
                      icon: originIcon,
                      color: AppColors.secondary,
                    ),
                    _Marker(
                      position: points.last,
                      icon: Icons.home_rounded,
                      color: AppColors.success,
                      pulse: t >= 1 ? null : pulse.value,
                    ),
                    _CourierMarker(position: courier, pulse: pulse.value),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Dessine les pâtés de maisons, un parc et une rivière.
class _CityPainter extends CustomPainter {
  _CityPainter({
    required this.cell,
    required this.origin,
    required this.isDark,
  });

  final double cell;
  final Offset origin;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final streets = isDark ? const Color(0xFF2B2E36) : Colors.white;
    final block = isDark ? const Color(0xFF1C1E24) : const Color(0xFFECEEF2);
    final park = isDark ? const Color(0xFF1E3326) : const Color(0xFFD6F0DC);
    final water = isDark ? const Color(0xFF1A2B3C) : const Color(0xFFCFE6FA);

    canvas.drawRect(Offset.zero & size, Paint()..color = streets);

    const gap = 14.0;
    final rows = (size.height / cell).ceil() + 1;
    final firstColumn = -(origin.dx / cell).ceil() - 1;
    final lastColumn = ((size.width - origin.dx) / cell).ceil();
    final blockPaint = Paint();
    for (var i = firstColumn; i <= lastColumn; i++) {
      for (var j = -1; j < rows; j++) {
        final rect = Rect.fromLTWH(
          origin.dx + i * cell + gap / 2,
          origin.dy + j * cell + gap / 2,
          cell - gap,
          cell - gap,
        );
        // Quelques pâtés deviennent des parcs (motif déterministe).
        blockPaint.color = (i + j * 3) % 7 == 0 ? park : block;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          blockPaint,
        );
      }
    }

    // Rivière qui traverse le bas de la zone visible, sous le trajet.
    final river = Path()
      ..moveTo(-20, cell * 4.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        cell * 3.9,
        size.width + 20,
        cell * 4.5,
      );
    canvas.drawPath(
      river,
      Paint()
        ..color = water
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CityPainter old) =>
      old.cell != cell || old.origin != origin || old.isDark != isDark;
}

/// Trajet : partie restante en pointillés clairs, partie parcourue en orange.
class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.metric, required this.progress});

  final PathMetric metric;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Pointillés pour le trajet restant
    final dashed = Paint.from(base)
      ..color = AppColors.primary.withValues(alpha: 0.35);
    const dash = 10.0;
    for (var d = metric.length * progress; d < metric.length; d += dash * 2) {
      canvas.drawPath(metric.extractPath(d, d + dash), dashed);
    }

    // Trajet déjà parcouru
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint.from(base)..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.progress != progress;
}

/// Épingle ronde (restaurant ou domicile) avec halo optionnel.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.position,
    required this.icon,
    required this.color,
    this.pulse,
  });

  final Offset position;
  final IconData icon;
  final Color color;
  final double? pulse;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    return Positioned(
      left: position.dx - size,
      top: position.dy - size,
      width: size * 2,
      height: size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse != null)
            Container(
              width: size * (1 + pulse!),
              height: size * (1 + pulse!),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.25 * (1 - pulse!)),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Marqueur du livreur : scooter dans un cercle orange avec halo pulsant.
class _CourierMarker extends StatelessWidget {
  const _CourierMarker({required this.position, required this.pulse});

  final Offset position;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    const size = 50.0;
    return Positioned(
      left: position.dx - size,
      top: position.dy - size,
      width: size * 2,
      height: size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * (1 + pulse * 0.9),
            height: size * (1 + pulse * 0.9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.3 * (1 - pulse)),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
