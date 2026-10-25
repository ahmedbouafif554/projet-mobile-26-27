import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/widgets/status_chips.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../catalog/providers/catalog_providers.dart';
import '../../providers/communication_providers.dart';
import '../widgets/review_card.dart';

/// Mes avis : statut de modération, modification et suppression.
class MyReviewsPage extends ConsumerWidget {
  const MyReviewsPage({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Review r) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Supprimer cet avis ?',
      message: 'Il disparaîtra de la page du restaurant.',
    );
    if (!confirmed) return;
    try {
      await ref.read(myReviewsProvider.notifier).remove(r);
      if (context.mounted) AppSnackbar.success(context, 'Avis supprimé');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(myReviewsProvider);
    final restaurants = ref.watch(restaurantsProvider).value ?? const [];
    String nameOf(String id) =>
        restaurants.where((r) => r.id == id).firstOrNull?.name ?? 'Restaurant';
    final list = reviews.value ?? const <Review>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children: [
            const PageTitle('Mes avis'),
            const SizedBox(height: AppSizes.md),
            if (reviews.isLoading && reviews.value == null)
              const ShimmerScope(
                child: SkeletonBox(height: 140, radius: AppSizes.radiusLg),
              )
            else if (list.isEmpty)
              EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'Aucun avis',
                message:
                    'Après une commande livrée, partagez votre expérience depuis vos commandes.',
                actionLabel: 'Mes commandes',
                onAction: () => context.go(FrontRoutes.orders),
              )
            else
              for (final (i, r) in list.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                  child: ReviewCard(
                    review: r,
                    header: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nameOf(r.restaurantId),
                                style: context.text.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  RatingStars(rating: r.rating, size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    Formatters.relative(r.createdAt),
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        reviewStatusChip(r.status),
                      ],
                    ),
                    footer: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (r.orderId != null)
                          TextButton.icon(
                            onPressed: () => context.push(
                              FrontRoutes.writeReview(r.orderId!),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Modifier'),
                          ),
                        TextButton.icon(
                          onPressed: () => _delete(context, ref, r),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Supprimer'),
                        ),
                      ],
                    ),
                  ).animate(delay: (50 * i).ms).fadeIn().slideY(begin: 0.05),
                ),
          ],
        ),
      ),
    );
  }
}
