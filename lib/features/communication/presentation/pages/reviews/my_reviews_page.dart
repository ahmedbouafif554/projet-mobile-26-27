import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../catalog/presentation/widgets/catalog_shimmers.dart';
import '../../../communication_routes.dart';
import '../../../models/review.dart';
import '../../controllers/reviews_controller.dart';
import '../../widgets/reviews/review_card.dart';
import 'review_dialogs.dart';

/// Avis laissés par l'utilisateur, avec leur statut de modération.
class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  late final ReviewsController _controller = ReviewsController.mine()..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        break; // On ne signale pas ses propres avis.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Mes avis'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const RestaurantListShimmer(count: 3);
          }
          if (_controller.error != null) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Chargement impossible',
              message: _controller.error!,
              actionLabel: 'Réessayer',
              onAction: _controller.load,
            );
          }
          final reviews = _controller.visible;
          if (reviews.isEmpty) {
            return EmptyState(
              icon: Icons.rate_review_outlined,
              title: 'Aucun avis pour le moment',
              message: 'Notez vos commandes livrées pour aider la communauté.',
              actionLabel: 'Voir mes commandes',
              onAction: () => context.go(AppRoutes.orders),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _controller.load,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  ReviewCard(
                        review: reviews[i],
                        heroOrigin: 'mine',
                        isMine: true,
                        showRestaurant: true,
                        showStatus: true,
                        onAction: (action) => _onAction(reviews[i], action),
                      )
                      .animate(
                        key: ValueKey('mine-${reviews[i].id}'),
                        delay: (60 * i).ms,
                      )
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.12, end: 0),
            ),
          );
        },
      ),
    );
  }
}
