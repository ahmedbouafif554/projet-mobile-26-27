import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/avatar.dart';
import '../../../../../shared/models/models.dart';
import '../../../../shared/catalog_widgets.dart';

/// Avis client : auteur, étoiles, commentaire, photos et réponse.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.footer,
    this.header,
  });

  final Review review;
  final Widget? footer;

  /// Remplace l'auteur (ex. nom du restaurant dans « Mes avis »).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header ??
              Row(
                children: [
                  Avatar(name: r.userName, imageUrl: r.userAvatar, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.userName, style: context.text.titleSmall),
                        Text(
                          Formatters.relative(r.createdAt),
                          style: context.text.labelSmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RatingStars(rating: r.rating),
                ],
              ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.comment, style: context.text.bodyMedium),
          ],
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppNetworkImage(r.photos[i], width: 70, height: 70),
                ),
              ),
            ),
          ],
          if (r.reply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Réponse de ${r.reply!.authorName}',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(r.reply!.text, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
          ?footer,
        ],
      ),
    );
  }
}
