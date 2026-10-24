import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../catalog/data/catalog_mock_data.dart';
import '../../../communication_routes.dart';
import '../../../models/review.dart';
import '../../controllers/reviews_controller.dart';
import '../../widgets/reviews/rating_summary_card.dart';
import '../../widgets/reviews/review_card.dart';
import 'review_dialogs.dart';

/// Avis d'un restaurant : résumé des notes, filtres, tri et liste.
class RestaurantReviewsPage extends StatefulWidget {
  const RestaurantReviewsPage({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<RestaurantReviewsPage> createState() => _RestaurantReviewsPageState();
}

class _RestaurantReviewsPageState extends State<RestaurantReviewsPage> {
  late final ReviewsController _controller = ReviewsController.restaurant(
    widget.restaurantId,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _write() async {
    final changed = await context.push<bool>(
      CommunicationRoutes.writeReview(restaurantId: widget.restaurantId),
    );
    if (changed == true) _controller.load();
  }

  Future<void> _onAction(Review review, ReviewAction action) async {
    switch (action) {
      case ReviewAction.edit:
        final changed = await context.push<bool>(
          CommunicationRoutes.editReview(review.id),
        );
        if (changed == true) _controller.load();
      case ReviewAction.delete:
        if (!await confirmDeleteReview(context)) return;
        final error = await _controller.delete(review);
        if (!mounted) return;
        error == null
            ? AppSnackbar.success(context, 'Avis supprimé')
            : AppSnackbar.error(context, error);
      case ReviewAction.report:
        final reason = await pickReportReason(context);
        if (reason == null) return;
        final error = await _controller.report(review, reason);
        if (!mounted) return;
        error == null
            ? AppSnackbar.success(
                context,
                'Merci, notre équipe va examiner cet avis.',
              )
            : AppSnackbar.error(context, error);
    }
  }

  Future<void> _toggleHelpful(Review review) async {
    final error = await _controller.toggleHelpful(review);
    if (error != null && mounted) AppSnackbar.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = CatalogMockData.restaurantById(widget.restaurantId);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: Column(
          children: [
            const Text('Avis clients'),
            Text(restaurant.name, style: context.text.labelSmall),
          ],
        ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
                onPressed: _write,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.rate_review_rounded),
                label: const Text('Donner mon avis'),
              )
              .animate(delay: 400.ms)
              .slideY(begin: 2, end: 0, curve: Curves.easeOutBack)
              .fadeIn(),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) return const _ReviewsSkeleton();
          if (_controller.error != null) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Chargement impossible',
              message: _controller.error!,
              actionLabel: 'Réessayer',
              onAction: _controller.load,
            );
          }
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final reviews = _controller.visible;
    // Origine Hero propre à chaque combinaison de filtres.
    final heroOrigin = 'resto${_controller.filterKey.hashCode}';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _controller.load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.sm,
                AppSizes.pagePadding,
                0,
              ),
              child: RatingSummaryCard(
                summary: _controller.summary,
                selectedStars: _controller.starFilter,
                onStarsTap: _controller.setStarFilter,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
            ),
          ),
          SliverToBoxAdapter(child: _FiltersBar(controller: _controller)),
          if (reviews.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Aucun avis',
                message: _controller.hasFilters
                    ? 'Aucun avis ne correspond à ces filtres.'
                    : 'Soyez le premier à donner votre avis !',
                actionLabel: _controller.hasFilters
                    ? 'Réinitialiser les filtres'
                    : null,
                onAction: _controller.hasFilters
                    ? _controller.clearFilters
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                4,
                AppSizes.pagePadding,
                100,
              ),
              sliver: SliverList.separated(
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final review = reviews[i];
                  final mine = review.isMine(_controller.me);
                  return ReviewCard(
                        review: review,
                        heroOrigin: heroOrigin,
                        isMine: mine,
                        showStatus: mine,
                        onHelpful: () => _toggleHelpful(review),
                        onAction: (action) => _onAction(review, action),
                      )
                      .animate(
                        key: ValueKey('${_controller.filterKey}-${review.id}'),
                        delay: (50 * i.clamp(0, 6)).ms,
                      )
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.12, end: 0);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({required this.controller});

  final ReviewsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.md, bottom: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding,
              ),
              children: [
                SelectableChip(
                  label: 'Tous',
                  selected: !controller.hasFilters,
                  onTap: controller.clearFilters,
                ),
                for (var stars = 5; stars >= 1; stars--) ...[
                  const SizedBox(width: 8),
                  SelectableChip(
                    label: '$stars',
                    icon: Icons.star_rounded,
                    selected: controller.starFilter == stars,
                    onTap: () => controller.setStarFilter(stars),
                  ),
                ],
                const SizedBox(width: 8),
                SelectableChip(
                  label: 'Avec photos',
                  icon: Icons.photo_library_rounded,
                  selected: controller.withPhotos,
                  onTap: controller.toggleWithPhotos,
                ),
                const SizedBox(width: 8),
                SelectableChip(
                  label: 'Avec réponse',
                  icon: Icons.storefront_rounded,
                  selected: controller.withReply,
                  onTap: controller.toggleWithReply,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              8,
              AppSizes.sm,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${controller.visible.length} avis affiché${controller.visible.length > 1 ? 's' : ''}',
                    style: context.text.bodySmall,
                  ),
                ),
                PopupMenuButton<ReviewSort>(
                  initialValue: controller.sort,
                  onSelected: controller.setSort,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  itemBuilder: (context) => [
                    for (final s in ReviewSort.values)
                      PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.sort.label,
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
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

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: ShimmerScope(
        child: Column(
          children: [
            const SkeletonBox(height: 190, radius: AppSizes.radiusLg),
            const SizedBox(height: AppSizes.md),
            const Row(
              children: [
                SkeletonBox(width: 60, height: 40),
                SizedBox(width: 8),
                SkeletonBox(width: 60, height: 40),
                SizedBox(width: 8),
                SkeletonBox(width: 60, height: 40),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            for (var i = 0; i < 3; i++) ...[
              const SkeletonBox(height: 130, radius: AppSizes.radiusLg),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
