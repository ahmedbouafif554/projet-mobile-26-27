import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/chat_providers.dart';
import '../../../../shared/repositories/repository_providers.dart';

// =============================================================================
// Module 5 (front office) : notifications, conversations et avis du client
// ou du livreur connecté.
// =============================================================================

/// Notifications reçues (personnelles et campagnes), les plus récentes
/// d'abord : lire, tout marquer comme lu, supprimer.
final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final userId = ref.watch(authServiceProvider.select((a) => a.user?.id));
    if (userId == null) return const [];
    return ref.watch(notificationRepositoryProvider).forUser(userId);
  }

  List<AppNotification> get _items => state.value ?? const [];

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    state = AsyncData([
      for (final n in _items)
        n.id == notification.id ? n.copyWith(isRead: true) : n,
    ]);
    await ref.read(notificationRepositoryProvider).markRead(notification.id);
  }

  Future<void> markAllRead() async {
    final userId = ref.read(authServiceProvider).user!.id;
    state = AsyncData([for (final n in _items) n.copyWith(isRead: true)]);
    await ref.read(notificationRepositoryProvider).markAllRead(userId);
  }

  /// Suppression (balayage). Une campagne envoyée à tous n'est masquée que
  /// pour la session.
  Future<void> remove(AppNotification notification) async {
    state = AsyncData([for (final n in _items) if (n.id != notification.id) n]);
    if (notification.userId != null) {
      await ref.read(notificationRepositoryProvider).delete(notification.id);
    }
  }

  /// Annule une suppression (snackbar « Annuler »).
  Future<void> restore(AppNotification notification) async {
    if (notification.userId != null) {
      await ref.read(notificationRepositoryProvider).create(notification);
    }
    final list = [..._items, notification]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(list);
  }
}

/// Préférences de notifications par catégorie.
final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, Map<NotificationType, bool>>(
      NotificationPrefsNotifier.new,
    );

class NotificationPrefsNotifier extends Notifier<Map<NotificationType, bool>> {
  @override
  Map<NotificationType, bool> build() => {
    for (final type in NotificationType.values) type: true,
  };

  void set(NotificationType type, bool enabled) =>
      state = {...state, type: enabled};
}

/// Canaux de notification (push, e-mail, SMS).
enum NotificationChannel {
  push('Notifications push', 'Sur ce téléphone'),
  email('E-mail', 'Récapitulatifs et reçus'),
  sms('SMS', 'Suivi de livraison uniquement');

  const NotificationChannel(this.label, this.description);
  final String label;
  final String description;
}

final notificationChannelsProvider =
    NotifierProvider<NotificationChannelsNotifier, Set<NotificationChannel>>(
      NotificationChannelsNotifier.new,
    );

class NotificationChannelsNotifier extends Notifier<Set<NotificationChannel>> {
  @override
  Set<NotificationChannel> build() => {
    NotificationChannel.push,
    NotificationChannel.email,
  };

  void toggle(NotificationChannel channel, bool enabled) => state = enabled
      ? {...state, channel}
      : state.where((c) => c != channel).toSet();
}

/// Conversations de l'utilisateur connecté.
final myChatsProvider = AsyncNotifierProvider<MyChatsController, List<Chat>>(
  MyChatsController.new,
);

class MyChatsController extends AsyncNotifier<List<Chat>> {
  @override
  Future<List<Chat>> build() async {
    final userId = ref.watch(authServiceProvider.select((a) => a.user?.id));
    ref.watch(chatsRevisionProvider);
    if (userId == null) return const [];
    return ref.watch(chatRepositoryProvider).forUser(userId);
  }

  Future<void> markRead(Chat chat) async {
    if (chat.unreadCount == 0) return;
    state = AsyncData([
      for (final c in state.value ?? const <Chat>[])
        c.id == chat.id ? c.copyWith(unreadCount: 0) : c,
    ]);
    await ref.read(chatRepositoryProvider).markRead(chat.id);
  }

  /// Conversation avec le support (créée au besoin).
  Future<Chat> supportChat() async {
    final user = ref.read(authServiceProvider).user!;
    final chats = await future;
    final existing = chats.where((c) => c.type == ChatType.support).firstOrNull;
    if (existing != null) return existing;
    final created = await ref
        .read(chatRepositoryProvider)
        .create(
          Chat(
            id: '',
            type: ChatType.support,
            title: 'Support SuperFaster',
            subtitle: 'Disponible 7j/7',
            participantIds: [user.id, 'u-admin'],
            lastMessage: 'Bonjour ! Comment pouvons-nous vous aider ?',
            lastMessageAt: DateTime.now(),
            isOnline: true,
          ),
        );
    await ref
        .read(messageRepositoryProvider)
        .create(
          Message(
            id: '',
            chatId: created.id,
            senderId: 'u-admin',
            senderName: 'Support',
            text: 'Bonjour ! Comment pouvons-nous vous aider ?',
            sentAt: DateTime.now(),
          ),
        );
    ref.invalidateSelf();
    return created;
  }

  /// Conversation avec le restaurant d'une commande (créée au besoin).
  Future<Chat> chatForOrder(Order order) async {
    final user = ref.read(authServiceProvider).user!;
    final chats = await future;
    final existing = chats
        .where((c) => c.orderId == order.id && c.type == ChatType.restaurant)
        .firstOrNull;
    if (existing != null) return existing;
    final restaurant = await ref
        .read(restaurantRepositoryProvider)
        .getById(order.restaurantId);
    final created = await ref
        .read(chatRepositoryProvider)
        .create(
          Chat(
            id: '',
            type: ChatType.restaurant,
            title: restaurant.name,
            subtitle: 'Commande #${order.reference}',
            avatarUrl: restaurant.imageUrl,
            participantIds: [user.id, ?restaurant.ownerId],
            orderId: order.id,
            lastMessageAt: DateTime.now(),
            isOnline: restaurant.isOpen,
          ),
        );
    ref.invalidateSelf();
    return created;
  }
}

/// Avis publiés d'un restaurant.
final restaurantReviewsProvider = FutureProvider.family<List<Review>, String>(
  (ref, restaurantId) => ref
      .watch(reviewRepositoryProvider)
      .forRestaurant(restaurantId, onlyPublished: true),
);

/// Avis écrits par le client connecté (CRUD).
final myReviewsProvider = AsyncNotifierProvider<MyReviewsController, List<Review>>(
  MyReviewsController.new,
);

class MyReviewsController extends AsyncNotifier<List<Review>> {
  @override
  Future<List<Review>> build() async {
    final userId = ref.watch(authServiceProvider.select((a) => a.user?.id));
    if (userId == null) return const [];
    final all = await ref.watch(reviewRepositoryProvider).getAll();
    return all.where((r) => r.userId == userId).toList();
  }

  /// Crée ou modifie un avis : il repasse en modération.
  Future<void> save(Review review) async {
    final repository = ref.read(reviewRepositoryProvider);
    final pending = review.copyWith(status: ReviewStatus.pending);
    review.id.isEmpty
        ? await repository.create(pending)
        : await repository.update(pending);
    ref
      ..invalidate(restaurantReviewsProvider(review.restaurantId))
      ..invalidateSelf();
    await future;
  }

  Future<void> remove(Review review) async {
    await ref.read(reviewRepositoryProvider).delete(review.id);
    ref
      ..invalidate(restaurantReviewsProvider(review.restaurantId))
      ..invalidateSelf();
    await future;
  }
}

/// « Utile » sur un avis (une fois par session).
final helpfulReviewsProvider =
    NotifierProvider<HelpfulReviewsNotifier, Set<String>>(
      HelpfulReviewsNotifier.new,
    );

class HelpfulReviewsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  Future<void> mark(Review review) async {
    if (state.contains(review.id)) return;
    state = {...state, review.id};
    await ref
        .read(reviewRepositoryProvider)
        .update(review.copyWith(helpfulCount: review.helpfulCount + 1));
    ref.invalidate(restaurantReviewsProvider(review.restaurantId));
  }
}
