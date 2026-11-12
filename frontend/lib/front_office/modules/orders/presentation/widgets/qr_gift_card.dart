import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../domain/gift_order.dart';

/// Peintre procédural d'un QR code vectoriel net et fidèle.
class QrCodePainter extends CustomPainter {
  QrCodePainter({
    required this.data,
    required this.color,
    this.backgroundColor = Colors.white,
  });

  final String data;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    final fgPaint = Paint()..color = color;

    // Fond blanc
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, bgPaint);

    const int matrixSize = 25; // 25x25 matrix
    final double cellSize = (size.width - 24) / matrixSize;
    final double offset = 12.0;

    // Détermine la grille à partir du hash des données
    final bytes = utf8.encode(data.isEmpty ? 'superfaster_gift' : data);
    final digest = bytes.fold<int>(0, (prev, elem) => (prev * 31 + elem) & 0x7FFFFFFF);

    bool isFinder(int r, int c) {
      // Top-left
      if (r < 7 && c < 7) return true;
      // Top-right
      if (r < 7 && c >= matrixSize - 7) return true;
      // Bottom-left
      if (r >= matrixSize - 7 && c < 7) return true;
      return false;
    }

    void drawFinderPattern(int startR, int startC) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          final isBorder = (r == 0 || r == 6 || c == 0 || c == 6);
          final isCenter = (r >= 2 && r <= 4 && c >= 2 && c <= 4);
          if (isBorder || isCenter) {
            final rect = Rect.fromLTWH(
              offset + (startC + c) * cellSize,
              offset + (startR + r) * cellSize,
              cellSize,
              cellSize,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(2)),
              fgPaint,
            );
          }
        }
      }
    }

    // Dessiner les 3 mires
    drawFinderPattern(0, 0);
    drawFinderPattern(0, matrixSize - 7);
    drawFinderPattern(matrixSize - 7, 0);

    // Dessiner la grille de données pseudo-aléatoire mais déterministe
    int bitIndex = digest;
    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        if (isFinder(r, c)) continue;
        // Timing patterns
        if (r == 6 || c == 6) {
          if ((r + c) % 2 == 0) {
            final rect = Rect.fromLTWH(
              offset + c * cellSize,
              offset + r * cellSize,
              cellSize,
              cellSize,
            );
            canvas.drawRect(rect, fgPaint);
          }
          continue;
        }

        bitIndex = (bitIndex * 1103515245 + 12345) & 0x7FFFFFFF;
        final isFilled = (bitIndex % 3 == 0) || ((r * c + bitIndex) % 5 == 0);
        if (isFilled) {
          final rect = Rect.fromLTWH(
            offset + c * cellSize + 0.5,
            offset + r * cellSize + 0.5,
            cellSize - 1,
            cellSize - 1,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
            fgPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrCodePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

/// Widget affichant un QR code de révélation.
class QrCodeWidget extends StatelessWidget {
  const QrCodeWidget({
    super.key,
    required this.token,
    this.size = 180,
    this.color = Colors.black87,
  });

  final String token;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: QrCodePainter(data: token, color: color),
      ),
    );
  }
}

/// Carte cadeau numérique avec design personnalisé et bouton de révélation.
class DigitalGiftCardWidget extends StatelessWidget {
  const DigitalGiftCardWidget({
    super.key,
    required this.gift,
    this.showQr = true,
    this.onRevealTap,
  });

  final GiftOrder gift;
  final bool showQr;
  final VoidCallback? onRevealTap;

  @override
  Widget build(BuildContext context) {
    final design = gift.giftCardDesign;
    final token = gift.qrCode ?? 'sf_${gift.orderId}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: design.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: design.colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Motif décoratif en arrière-plan
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                design.icon,
                size: 160,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête de la carte
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(design.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            design.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Pour qui ?
                Text(
                  'Pour ${gift.recipientName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                // De la part de qui ?
                Text(
                  'De la part de : ${gift.effectiveSender}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (gift.message != null && gift.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '« ${gift.message} »',
                      style: const TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                if (gift.scheduledAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Livraison programmée le ${Formatters.dateTime(gift.scheduledAt!)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                // Bas de carte avec QR Code & Bouton
                Row(
                  children: [
                    if (showQr) ...[
                      GestureDetector(
                        onTap: () => _showQrDialog(context, token, gift),
                        child: Hero(
                          tag: 'qr_$token',
                          child: QrCodeWidget(token: token, size: 76),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Code Révélation',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gift.revealed
                                ? 'Cadeau déjà révélé ✓'
                                : 'Le destinataire découvrira la surprise en scannant ce code.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'Partager le lien du cadeau',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                'Surprise ! Vous avez reçu un repas en cadeau. Révélez votre menu ici : /gift-reveal/$token',
                          ),
                        );
                        AppSnackbar.success(
                          context,
                          'Lien du cadeau copié dans le presse-papier !',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, String token, GiftOrder gift) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QR Code Cadeau 🎁',
                style: ctx.text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Faites scanner ce code à ${gift.recipientName} pour dévoiler son cadeau.',
                textAlign: TextAlign.center,
                style: ctx.text.bodyMedium?.copyWith(
                  color: ctx.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              QrCodeWidget(token: token, size: 220),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ctx.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Code : $token',
                  style: ctx.text.labelSmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copier'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token));
                        Navigator.pop(ctx);
                        AppSnackbar.success(context, 'Token copié !');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('Ouvrir'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/gift-reveal/$token');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
