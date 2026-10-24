import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../catalog/data/catalog_mock_data.dart';
import '../../../communication_routes.dart';
import '../../../models/review.dart';
import '../../pages/reviews/photo_viewer_page.dart';
import 'star_rating.dart';

/// Actions disponibles dans le menu d'un avis.
enum ReviewAction { edit, delete, report }

/// Carte d'un avis : auteur, note, critères, commentaire repliable,
/// photos (Hero vers la visionneuse), réponse du restaurant et bouton « Utile ».
class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.heroOrigin,
    this.isMine = false,
    this.showRestaurant = false,
    this.showStatus = false,
    this.onHelpful,
    this.onAction,
    this.footer,
  });

  final Review review;

  /// Préfixe unique des tags Hero des photos.
  final String heroOrigin;
  final bool isMine;

  /// Affiche le nom du restaurant (pages « Mes avis » et modération).
  final bool showRestaurant;

  /// Affiche le statut de modération quand l'avis n'est pas publié.
  final bool showStatus;
  final VoidCallback? onHelpful;
  final ValueChanged<ReviewAction>? onAction;

  /// Zone libre sous la carte (boutons de modération…).
  final Widget? footer;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final longComment = review.comment.length > 160;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: widget.isMine
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : null,
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showRestaurant)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      CatalogMockData.restaurantById(review.restaurantId).name,
                      style: context.text.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _Header(
            review: widget.review,
            isMine: widget.isMine,
            onAction: widget.onAction,
          ),
          if (widget.showStatus && review.status != ReviewStatus.approved) ...[
            const SizedBox(height: 10),
            _StatusBadge(status: review.status),
          ],
          if (review.criteria.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in review.criteria.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.key.label} ${entry.value}/5',
                      style: context.text.labelSmall,
                    ),
                  ),
              ],
            ),
          ],
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            AnimatedSize(
              duration: AppDurations.medium,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: Text(
                review.comment,
                style: context.text.bodyMedium,
                maxLines: _expanded ? null : 4,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (longComment)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Voir moins' : 'Lire la suite',
                    style: context.text.labelLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
          if (review.hasPhotos) ...[
            const SizedBox(height: 12),
            _Photos(review: review, heroOrigin: widget.heroOrigin),
          ],
          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: review.reply == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ReplyBox(reply: review.reply!),
                  ),
          ),
          if (widget.onHelpful != null && !widget.isMine) ...[
            const SizedBox(height: 12),
            _HelpfulButton(review: review, onTap: widget.onHelpful!),
          ],
          if (widget.footer != null) ...[
            const SizedBox(height: 12),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.review, required this.isMine, this.onAction});

  final Review review;
  final bool isMine;
  final ValueChanged<ReviewAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final initials = review.authorName.isEmpty
        ? '?'
        : review.authorName.substring(0, 1);

    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 42,
            height: 42,
            child: review.authorAvatarUrl == null
                ? Container(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    alignment: Alignment.center,
                    child: Text(initials, style: context.text.titleMedium),
                  )
                : AppNetworkImage(
                    review.authorAvatarUrl!,
                    width: 42,
                    height: 42,
                    fallbackIcon: Icons.person_rounded,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      isMine
                          ? '${review.authorName} (vous)'
                          : review.authorName,
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  StarRatingDisplay(rating: review.rating.toDouble(), size: 15),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${Formatters.relative(review.createdAt)}${review.isEdited ? ' • modifié' : ''}',
                      style: context.text.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onAction != null)
          PopupMenuButton<ReviewAction>(
            tooltip: 'Options',
            icon: Icon(
              Icons.more_vert_rounded,
              color: context.palette.textSecondary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            onSelected: onAction,
            itemBuilder: (context) => [
              if (isMine) ...[
                const PopupMenuItem(
                  value: ReviewAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Modifier'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: ReviewAction.delete,
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Supprimer',
                      style: TextStyle(color: AppColors.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ] else
                const PopupMenuItem(
                  value: ReviewAction.report,
                  child: ListTile(
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Signaler'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ReviewStatus.pending => (AppColors.warning, Icons.hourglass_top_rounded),
      ReviewStatus.rejected => (AppColors.error, Icons.block_rounded),
      ReviewStatus.approved => (AppColors.success, Icons.check_circle_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: context.text.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.review, required this.heroOrigin});

  final Review review;
  final String heroOrigin;

  @override
  Widget build(BuildContext context) {
    final tags = [
      for (var i = 0; i < review.photos.length; i++)
        reviewPhotoTag(heroOrigin, review.id, i),
    ];
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: review.photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Pressable(
          onTap: () => context.push(
            CommunicationRoutes.photos,
            extra: PhotoViewerArgs(
              photos: review.photos,
              heroTags: tags,
              initialIndex: i,
            ),
          ),
          scale: 0.94,
          child: Hero(
            tag: tags[i],
            child: AppNetworkImage(
              review.photos[i],
              width: 76,
              height: 76,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              fallbackIcon: Icons.photo_rounded,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyBox extends StatelessWidget {
  const _ReplyBox({required this.reply});

  final ReviewReply reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Réponse de ${reply.authorName}',
                  style: context.text.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Formatters.relative(reply.createdAt),
                style: context.text.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(reply.message, style: context.text.bodyMedium),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0);
  }
}

class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({required this.review, required this.onTap});

  final Review review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = review.isHelpfulByMe;
    final color = active ? AppColors.primary : context.palette.textSecondary;

    return Pressable(
      onTap: onTap,
      scale: 0.9,
      haptic: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: active ? AppColors.primary : context.palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                  active
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  size: 16,
                  color: color,
                )
                // Petit rebond à chaque changement d'état.
                .animate(key: ValueKey(active))
                .scaleXY(
                  begin: 0.5,
                  end: 1,
                  duration: 450.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(width: 6),
            Text(
              'Utile (${review.helpfulCount})',
              style: context.text.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
