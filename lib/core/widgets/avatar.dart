import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_network_image.dart';

/// Photo ronde d'une personne ou d'un restaurant, avec les initiales si
/// l'image est absente.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.border = false,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// Liseré blanc (sur fond coloré).
  final bool border;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
    final image = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? fallback
            : AppNetworkImage(
                url,
                width: size,
                height: size,
                fallbackIcon: Icons.person_rounded,
              ),
      ),
    );
    if (!border) return image;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: image,
    );
  }
}
