import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/chat_providers.dart';
import '../../../shared/repositories/campaigns/campaign_repository.dart';
import '../../../shared/repositories/chats/chat_repository.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../../../shared/repositories/reviews/review_repository.dart';
import '../../shared/entity_list_controller.dart';

/// Avis (Module 5) : modération (admin) ou avis de son restaurant
/// (restaurateur, qui peut répondre).
final reviewsControllerProvider =
    AsyncNotifierProvider<ReviewsController, List<Review>>(
      ReviewsController.new,
    );

class ReviewsController extends EntityListController<Review> {
  @override
  ReviewRepository get repository => ref.read(reviewRepositoryProvider);

  @override
  Future<List<Review>> build() {
    ref.watch(authServiceProvider.select((a) => a.user?.id));
    return load();
  }

  @override
  Future<List<Review>> load() {
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.restaurant && user?.restaurantId != null
        ? repository.forRestaurant(user!.restaurantId!)
        : repository.getAll();
  }

  Future<void> moderate(Review review, ReviewStatus status) =>
      run(() => repository.moderate(review.id, status));

  Future<void> reply(Review review, String text) {
    final user = ref.read(authServiceProvider).user!;
    return run(
      () => repository.reply(
        review.id,
        ReviewReply(
          text: text,
          authorName: user.role == UserRole.admin
              ? 'Équipe SuperFaster'
              : user.fullName,
          at: DateTime.now(),
        ),
      ),
    );
  }
}

/// Campagnes de notifications (Module 5, admin).
final campaignsControllerProvider =
    AsyncNotifierProvider<CampaignsController, List<NotificationCampaign>>(
      CampaignsController.new,
    );

class CampaignsController extends EntityListController<NotificationCampaign> {
  @override
  CampaignRepository get repository => ref.read(campaignRepositoryProvider);

  Future<void> send(NotificationCampaign campaign) =>
      run(() => repository.send(campaign.id));
}

/// Conversations (Module 5) : supervision de toutes les conversations
/// (admin) ou conversations du restaurateur.
final chatsControllerProvider =
    AsyncNotifierProvider<ChatsController, List<Chat>>(ChatsController.new);

class ChatsController extends EntityListController<Chat> {
  @override
  ChatRepository get repository => ref.read(chatRepositoryProvider);

  @override
  Future<List<Chat>> build() {
    ref.watch(authServiceProvider.select((a) => a.user?.id));
    // Un message envoyé met à jour l'aperçu de la conversation.
    ref.watch(chatsRevisionProvider);
    return load();
  }

  @override
  Future<List<Chat>> load() {
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.restaurant
        ? repository.forUser(user!.id)
        : repository.getAll();
  }

  Future<void> setFlagged(Chat chat, bool flagged) =>
      run(() => repository.setFlagged(chat.id, flagged));

  Future<void> markRead(Chat chat) => run(() => repository.markRead(chat.id));
}
