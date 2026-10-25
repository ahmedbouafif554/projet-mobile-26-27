import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import '../catalog/catalog_controllers.dart';
import 'communication_controllers.dart';

enum _ReviewGroup {
  all('Tous', AppColors.primary),
  pending('À modérer', AppColors.warning),
  published('Publiés', AppColors.success),
  rejected('Refusés', AppColors.error),
  unanswered('Sans réponse', AppColors.info);

  const _ReviewGroup(this.label, this.color);
  final String label;
  final Color color;

  bool test(Review r) => switch (this) {
    all => true,
    pending => r.status == ReviewStatus.pending,
    published => r.status == ReviewStatus.approved,
    rejected => r.status == ReviewStatus.rejected,
    unanswered => r.status == ReviewStatus.approved && r.reply == null,
  };
}

/// Module 5 : avis clients. L'admin modère (publier, refuser, supprimer) ;
/// le restaurateur répond aux avis publiés de son restaurant.
class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({super.key});

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  late _ReviewGroup _group =
      ref.read(authServiceProvider).can(Permission.moderateReviews)
      ? _ReviewGroup.pending
      : _ReviewGroup.unanswered;
  String _query = '';
  int _shown = 8;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authServiceProvider).can(
      Permission.moderateReviews,
    );
    final reviews = ref.watch(reviewsControllerProvider);
    final restaurants = ref.watch(restaurantsControllerProvider).value ?? [];
    final all = reviews.value ?? const <Review>[];
    String restaurantName(String id) =>
        restaurants.where((r) => r.id == id).firstOrNull?.name ?? '';
    final groups = isAdmin
        ? _ReviewGroup.values
        : [_ReviewGroup.all, _ReviewGroup.unanswered, _ReviewGroup.published];
    final q = _query.toLowerCase();
    final visible = all
        .where(_group.test)
        .where(
          (r) =>
              q.isEmpty ||
              '${r.userName} ${r.comment} ${restaurantName(r.restaurantId)}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();

    return BoPage(
      title: 'Avis clients',
      subtitle: isAdmin
          ? 'Modérez les avis avant leur publication dans l’application.'
          : 'Répondez à vos clients : une réponse rassure les futurs clients.',
      children: [
        SplitRow(
          leftFlex: 2,
          rightFlex: 3,
          breakpoint: 820,
          left: _RatingSummary(
            reviews: all.where((r) => r.status == ReviewStatus.approved).toList(),
          ),
          right: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchField(
                  hint: 'Client, commentaire, restaurant…',
                  dense: true,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _shown = 8;
                  }),
                ),
                const SizedBox(height: AppSizes.md),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    for (final g in groups)
                      SummaryPill(
                        label: g.label,
                        value: all.where(g.test).length,
                        color: g.color,
                        selected: _group == g,
                        onTap: () => setState(() {
                          _group = g;
                          _shown = 8;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        boGap,
        if (reviews.isLoading && reviews.value == null)
          ShimmerScope(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonBox(height: 150, radius: AppSizes.radiusLg),
                  ),
              ],
            ),
          )
        else if (visible.isEmpty)
          const AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.reviews_outlined,
              title: 'Aucun avis',
              message: 'Aucun avis ne correspond à ce filtre.',
            ),
          )
        else ...[
          for (final (i, review) in visible.take(_shown).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewCard(
                key: ValueKey(review.id),
                review: review,
                restaurantName: isAdmin
                    ? restaurantName(review.restaurantId)
                    : null,
                canModerate: isAdmin,
              ).animate(delay: (40 * (i % 8)).ms).fadeIn().slideY(begin: 0.05),
            ),
          if (visible.length > _shown)
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _shown += 8),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('Voir plus (${visible.length - _shown})'),
              ),
            ),
        ],
      ],
    );
  }
}

/// Note moyenne et répartition des étoiles (avis publiés).
class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final count = reviews.length;
    final average = count == 0
        ? 0.0
        : reviews.fold<int>(0, (s, r) => s + r.rating) / count;
    return AppCard(
      child: Row(
        children: [
          Column(
            children: [
              Text(
                Formatters.rating(average),
                style: context.text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              _Stars(rating: average.round(), size: 18),
              const SizedBox(height: 4),
              Text(
                '$count avis publiés',
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.lg),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text('$star', style: context.text.labelMedium),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: count == 0
                                  ? 0
                                  : reviews
                                            .where((r) => r.rating == star)
                                            .length /
                                        count,
                            ),
                            duration: AppDurations.slow,
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 8,
                                color: AppColors.warning,
                                backgroundColor: context.palette.surfaceMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: AppColors.warning,
        ),
    ],
  );
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    super.key,
    required this.review,
    required this.restaurantName,
    required this.canModerate,
  });

  final Review review;
  final String? restaurantName;
  final bool canModerate;

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref,
    ReviewStatus status,
  ) async {
    try {
      await ref.read(reviewsControllerProvider.notifier).moderate(review, status);
      if (context.mounted) {
        AppSnackbar.success(
          context,
          status == ReviewStatus.approved ? 'Avis publié' : 'Avis refusé',
        );
      }
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Supprimer cet avis ?',
      message: 'L’avis de ${review.userName} sera supprimé définitivement.',
    );
    if (!confirmed) return;
    try {
      await ref.read(reviewsControllerProvider.notifier).remove(review.id);
      if (context.mounted) AppSnackbar.success(context, 'Avis supprimé');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  Future<void> _reply(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReplyDialog(review: review),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await ref.read(reviewsControllerProvider.notifier).reply(review, text.trim());
      if (context.mounted) AppSnackbar.success(context, 'Réponse publiée');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = review;
    final muted = context.text.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(name: r.userName, imageUrl: r.userAvatar, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.userName, style: context.text.titleSmall),
                    Text(
                      [
                        ?restaurantName,
                        Formatters.relative(r.createdAt),
                      ].join(' • '),
                      style: muted,
                    ),
                  ],
                ),
              ),
              reviewStatusChip(r.status),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.md,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Stars(rating: r.rating, size: 18),
              if (r.foodRating != null) Text('Plats ${r.foodRating}/5', style: muted),
              if (r.deliveryRating != null)
                Text('Livraison ${r.deliveryRating}/5', style: muted),
              if (r.packagingRating != null)
                Text('Emballage ${r.packagingRating}/5', style: muted),
              if (r.reportCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Signalé ${r.reportCount}×',
                      style: context.text.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(r.comment, style: context.text.bodyMedium),
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in r.photos)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AppNetworkImage(photo, width: 72, height: 72),
                  ),
              ],
            ),
          ],
          if (r.reply != null) ...[
            const SizedBox(height: AppSizes.md),
            Container(
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
                    'Réponse de ${r.reply!.authorName} • ${Formatters.relative(r.reply!.at)}',
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(r.reply!.text, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            alignment: WrapAlignment.end,
            children: [
              if (canModerate && r.status != ReviewStatus.rejected)
                OutlinedButton.icon(
                  onPressed: () => _moderate(context, ref, ReviewStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: const Text('Refuser'),
                ),
              if (canModerate && r.status != ReviewStatus.approved)
                FilledButton.icon(
                  onPressed: () => _moderate(context, ref, ReviewStatus.approved),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Publier'),
                ),
              if (r.status == ReviewStatus.approved)
                FilledButton.tonalIcon(
                  onPressed: () => _reply(context, ref),
                  icon: Icon(
                    r.reply == null ? Icons.reply_rounded : Icons.edit_rounded,
                    size: 18,
                  ),
                  label: Text(
                    r.reply == null ? 'Répondre' : 'Modifier la réponse',
                  ),
                ),
              if (canModerate)
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.review});

  final Review review;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final _controller = TextEditingController(
    text: widget.review.reply?.text,
  );

  static const _templates = [
    'Merci beaucoup pour votre avis, à très bientôt !',
    'Merci pour votre retour, nous transmettons vos compliments à l’équipe.',
    'Nous sommes désolés pour ce désagrément, nous allons faire mieux.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Répondre à ${widget.review.userName}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '« ${widget.review.comment} »',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: context.palette.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Votre réponse publique…',
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _templates)
                  ActionChip(
                    label: Text(
                      t.length > 32 ? '${t.substring(0, 30)}…' : t,
                      style: context.text.labelSmall,
                    ),
                    onPressed: () => setState(() => _controller.text = t),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _controller.text),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Publier la réponse'),
        ),
      ],
    );
  }
}
