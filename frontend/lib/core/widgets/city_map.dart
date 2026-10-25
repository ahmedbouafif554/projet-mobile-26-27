import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Plan stylisé de Paris (rues, Seine, parcs) avec des trajets en
/// pointillés animés : carte des livreurs (back office) et suivi de
/// commande (front office), sans service de cartographie.
class CityMapPainter extends CustomPainter {
  CityMapPainter({required this.dark, required this.routes, required this.dash});

  final bool dark;
  final List<(Offset, Offset)> routes;

  /// Avancement de l'animation des pointillés (0–1).
  final double dash;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = dark ? const Color(0xFF1E2127) : const Color(0xFFF2EFE9);
    final street = dark ? const Color(0xFF2C3038) : Colors.white;
    final major = dark ? const Color(0xFF3A3F49) : const Color(0xFFFFE7C2);
    final park = dark ? const Color(0xFF1F3527) : const Color(0xFFCDEBC5);
    final water = dark ? const Color(0xFF1C3550) : const Color(0xFFAADAFF);

    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    // Parcs.
    final parkPaint = Paint()..color = park;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.05, h * 0.62, w * 0.16, h * 0.2),
          const Radius.circular(18),
        ),
        parkPaint,
      )
      ..drawOval(Rect.fromLTWH(w * 0.7, h * 0.08, w * 0.14, h * 0.16), parkPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.42, h * 0.74, w * 0.12, h * 0.14),
          const Radius.circular(14),
        ),
        parkPaint,
      );

    // Rues secondaires (grille légèrement inclinée).
    final minor = Paint()
      ..color = street
      ..strokeWidth = 3;
    for (var x = -0.2; x < 1.2; x += 0.07) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * (x + 0.08), h), minor);
    }
    for (var y = 0.0; y < 1.1; y += 0.09) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * (y - 0.04)), minor);
    }

    // Grands boulevards.
    final boulevard = Paint()
      ..color = major
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, h * 0.3)
          ..quadraticBezierTo(w * 0.5, h * 0.18, w, h * 0.34),
        boulevard,
      )
      ..drawLine(Offset(w * 0.32, 0), Offset(w * 0.4, h), boulevard)
      ..drawLine(Offset(w * 0.76, 0), Offset(w * 0.62, h), boulevard)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5),
          width: w * 0.9,
          height: h * 0.86,
        ),
        boulevard..strokeWidth = 5,
      );

    // La Seine.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.58)
        ..cubicTo(w * 0.25, h * 0.48, w * 0.4, h * 0.72, w * 0.6, h * 0.6)
        ..cubicTo(w * 0.75, h * 0.5, w * 0.85, h * 0.66, w, h * 0.7),
      Paint()
        ..color = water
        ..strokeWidth = 16
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Trajets des courses : pointillés animés restaurant → livreur.
    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in routes) {
      final total = (to - from).distance;
      if (total < 1) continue;
      final dir = (to - from) / total;
      const dashLength = 8.0;
      const gap = 6.0;
      var d = -(dash * (dashLength + gap) * 4) % (dashLength + gap);
      while (d < total) {
        final start = from + dir * math.max(0, d);
        final end = from + dir * math.min(total, d + dashLength);
        if (d + dashLength > 0) canvas.drawLine(start, end, routePaint);
        d += dashLength + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CityMapPainter old) =>
      old.dark != dark || old.dash != dash || old.routes != routes;
}
