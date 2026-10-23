import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../models/payment_method.dart';

/// Représentation visuelle d'une carte bancaire (fictive).
class PaymentCardVisual extends StatelessWidget {
  const PaymentCardVisual({
    super.key,
    required this.type,
    required this.number,
    required this.holder,
    required this.expiry,
  });

  final PaymentType type;

  /// Numéro tel qu'affiché (ex. : « •••• •••• •••• 4242 »).
  final String number;
  final String holder;
  final String expiry;

  List<Color> get _colors => type == PaymentType.mastercard
      ? const [Color(0xFFFF8A50), Color(0xFFE04410)]
      : const [Color(0xFF3A3A48), Color(0xFF15151A)];

  @override
  Widget build(BuildContext context) {
    final white70 = Colors.white.withValues(alpha: 0.7);

    return AspectRatio(
      aspectRatio: 1.62,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        padding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          boxShadow: [
            BoxShadow(
              color: _colors.last.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cercles décoratifs
            Positioned(
              right: -80,
              top: -90,
              child: _circle(200, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              left: -60,
              bottom: -110,
              child: _circle(180, Colors.white.withValues(alpha: 0.05)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF5D88A), Color(0xFFC9A44C)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.contactless_rounded, color: white70),
                    const Spacer(),
                    _BrandLogo(type: type),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    number,
                    style: context.text.titleLarge?.copyWith(
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Labeled(
                        label: 'TITULAIRE',
                        value: holder.isEmpty
                            ? 'NOM PRÉNOM'
                            : holder.toUpperCase(),
                      ),
                    ),
                    _Labeled(
                      label: 'EXPIRE',
                      value: expiry.isEmpty ? 'MM/AA' : expiry,
                    ),
                  ],
                ),
              ],
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

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelLarge?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// Logo stylisé (dessiné, sans asset de marque).
class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.type});

  final PaymentType type;

  @override
  Widget build(BuildContext context) {
    if (type == PaymentType.mastercard) {
      return SizedBox(
        width: 46,
        height: 28,
        child: Stack(
          children: [
            Positioned(left: 0, child: _dot(const Color(0xFFEB001B))),
            Positioned(right: 0, child: _dot(const Color(0xCCF79E1B))),
          ],
        ),
      );
    }
    return Text(
      'VISA',
      style: context.text.titleLarge?.copyWith(
        color: Colors.white,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
