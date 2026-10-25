import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/chat_providers.dart';
import '../../router/back_routes.dart';
import '../../shell/bo_page.dart';
import '../catalog/catalog_controllers.dart';
import 'communication_controllers.dart';

/// Nom affiché d'un participant : restaurant pour un restaurateur, sinon
/// prénom et nom.
String participantName(
  String id,
  Map<String, User> users,
  List<Restaurant> restaurants,
) {
  final user = users[id];
  if (user == null) return 'Utilisateur';
  if (user.role == UserRole.restaurant) {
    final r = restaurants.where((r) => r.id == user.restaurantId).firstOrNull;
    if (r != null) return r.name;
  }
  if (user.role == UserRole.admin) return 'Support SuperFaster';
  return user.fullName;
}

/// Titre d'une conversation vu depuis le back office : les autres
/// participants (« Emma Leroy ↔ Pizza Napoli » en supervision).
String chatTitle(
  Chat chat,
  String myId,
  Map<String, User> users,
  List<Restaurant> restaurants,
) {
  final others = chat.participantIds.where((id) => id != myId).toList();
  if (others.isEmpty) return chat.title;
  return others.map((id) => participantName(id, users, restaurants)).join(' ↔ ');
}

/// Photo d'une conversation : le premier autre participant (image du
/// restaurant pour un restaurateur).
String? chatAvatar(
  Chat chat,
  String myId,
  Map<String, User> users,
  List<Restaurant> restaurants,
) {
  final otherId = chat.participantIds.where((id) => id != myId).firstOrNull;
  final user = users[otherId];
  if (user == null) return chat.avatarUrl;
  if (user.role == UserRole.restaurant) {
    final r = restaurants.where((r) => r.id == user.restaurantId).firstOrNull;
    if (r != null) return r.imageUrl;
  }
  return user.avatarUrl ?? chat.avatarUrl;
}

/// Module 5 : conversations. Le restaurateur échange avec ses clients ;
/// l'admin supervise toutes les conversations (signalement, intervention).
class ChatsPage extends ConsumerWidget {
  const ChatsPage({super.key, this.chatId});

  final String? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authServiceProvider).can(
      Permission.superviseChats,
    );
    return BoPage(
      title: 'Conversations',
      subtitle: isAdmin
          ? 'Supervision des échanges entre clients, restaurants et livreurs.'
          : 'Échangez avec vos clients à propos de leurs commandes.',
      scrollable: false,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final list = _ChatList(selectedId: chatId);
              if (!wide) {
                return chatId == null
                    ? list
                    : _Conversation(chatId: chatId!, showBack: true);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: list),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: chatId == null
                        ? const AppCard(
                            child: EmptyState(
                              compact: true,
                              icon: Icons.forum_outlined,
                              title: 'Sélectionnez une conversation',
                              message:
                                  'Les messages s’afficheront ici.',
                            ),
                          )
                        : _Conversation(
                            key: ValueKey(chatId),
                            chatId: chatId!,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatList extends ConsumerStatefulWidget {
  const _ChatList({required this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<_ChatList> {
  String _query = '';

  /// null = toutes, 'unread' ou 'flagged'.
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authServiceProvider).user;
    if (me == null) return const SizedBox.shrink();
    final isAdmin = me.role == UserRole.admin;
    final chats = ref.watch(chatsControllerProvider);
    final users = ref.watch(usersByIdProvider).value ?? const {};
    final restaurants = ref.watch(restaurantsControllerProvider).value ?? [];
    final q = _query.toLowerCase();
    final visible = (chats.value ?? const <Chat>[]).where((c) {
      if (_filter == 'unread' && c.unreadCount == 0) return false;
      if (_filter == 'flagged' && !c.isFlagged) return false;
      if (q.isEmpty) return true;
      return '${chatTitle(c, me.id, users, restaurants)} ${c.lastMessage ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: AppSearchField(
              hint: 'Rechercher une conversation…',
              dense: true,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final (value, label) in [
                  (null, 'Toutes'),
                  ('unread', 'Non lues'),
                  if (isAdmin) ('flagged', 'Signalées'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 17),
          Expanded(
            child: chats.isLoading && chats.value == null
                ? ShimmerScope(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: SkeletonBox(height: 60),
                          ),
                      ],
                    ),
                  )
                : visible.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Aucune conversation',
                    message: 'Aucune conversation ne correspond.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final chat = visible[i];
                      return _ChatTile(
                        chat: chat,
                        title: chatTitle(chat, me.id, users, restaurants),
                        avatarUrl: chatAvatar(chat, me.id, users, restaurants),
                        selected: chat.id == widget.selectedId,
                        onTap: () => context.go(BackRoutes.chat(chat.id)),
                      ).animate(delay: (30 * i).ms).fadeIn(duration: 250.ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.title,
    required this.avatarUrl,
    required this.selected,
    required this.onTap,
  });

  final Chat chat;
  final String title;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount > 0;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  Avatar(name: title, imageUrl: avatarUrl, size: 44),
                  if (chat.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.relative(chat.lastMessageAt),
                          style: context.text.labelSmall?.copyWith(
                            color: unread
                                ? AppColors.primary
                                : context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (chat.isFlagged) ...[
                          const Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            chat.lastMessage ?? chat.subtitle ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: unread
                                  ? context.colors.onSurface
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Conversation ouverte : en-tête, bulles et zone de saisie.
class _Conversation extends ConsumerStatefulWidget {
  const _Conversation({super.key, required this.chatId, this.showBack = false});

  final String chatId;
  final bool showBack;

  @override
  ConsumerState<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<_Conversation> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _markedRead = false;

  static const _quickReplies = [
    'Votre commande est en préparation 👨‍🍳',
    'Elle part dans quelques minutes !',
    'Désolé pour l’attente, merci de votre patience.',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(Chat chat, [String? quick]) async {
    final text = (quick ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await ref
          .read(chatMessagesProvider(widget.chatId).notifier)
          .send(text, chat: chat);
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    }
  }

  Future<void> _toggleFlag(Chat chat) async {
    try {
      await ref
          .read(chatsControllerProvider.notifier)
          .setFlagged(chat, !chat.isFlagged);
      if (mounted) {
        AppSnackbar.success(
          context,
          chat.isFlagged ? 'Signalement retiré' : 'Conversation signalée',
        );
      }
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authServiceProvider).user;
    if (me == null) return const SizedBox.shrink();
    final chat = ref
        .watch(chatsControllerProvider)
        .value
        ?.where((c) => c.id == widget.chatId)
        .firstOrNull;
    final users = ref.watch(usersByIdProvider).value ?? const {};
    final restaurants = ref.watch(restaurantsControllerProvider).value ?? [];
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final typing = ref.watch(chatTypingProvider(widget.chatId));

    ref.listen(chatMessagesProvider(widget.chatId), (previous, next) {
      if ((next.value?.length ?? 0) != (previous?.value?.length ?? 0)) {
        _scrollToEnd();
      }
    });
    ref.listen(chatTypingProvider(widget.chatId), (_, isTyping) {
      if (isTyping) _scrollToEnd();
    });

    if (chat == null) {
      return AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.forum_outlined,
          title: 'Conversation introuvable',
          message: 'Elle a peut-être été supprimée.',
          actionLabel: 'Retour',
          onAction: () => context.go(BackRoutes.chats),
        ),
      );
    }

    // Ouvrir la conversation la marque comme lue (une fois).
    if (!_markedRead && chat.unreadCount > 0) {
      _markedRead = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(chatsControllerProvider.notifier).markRead(chat),
      );
    }

    final isAdmin = me.role == UserRole.admin;
    final participant = chat.participantIds.contains(me.id);
    final title = chatTitle(chat, me.id, users, restaurants);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: Row(
              children: [
                if (widget.showBack)
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => context.go(BackRoutes.chats),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                else
                  const SizedBox(width: 6),
                Avatar(
                  name: title,
                  imageUrl: chatAvatar(chat, me.id, users, restaurants),
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                      Text(
                        typing
                            ? 'En train d’écrire…'
                            : chat.subtitle ?? chat.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: typing
                              ? AppColors.primary
                              : context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (chat.orderId != null)
                  IconButton(
                    tooltip: 'Voir la commande',
                    onPressed: () =>
                        context.go(BackRoutes.order(chat.orderId!)),
                    icon: const Icon(Icons.receipt_long_rounded),
                  ),
                if (isAdmin)
                  IconButton(
                    tooltip: chat.isFlagged
                        ? 'Retirer le signalement'
                        : 'Signaler',
                    onPressed: () => _toggleFlag(chat),
                    icon: Icon(
                      chat.isFlagged
                          ? Icons.flag_rounded
                          : Icons.outlined_flag_rounded,
                      color: chat.isFlagged ? AppColors.error : null,
                    ),
                  ),
              ],
            ),
          ),
          if (isAdmin && !participant)
            Container(
              color: AppColors.info.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode supervision : vos messages sont signés « Support SuperFaster ».',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSizes.md),
                itemCount: list.length + (typing ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == list.length) return const _TypingBubble();
                  final m = list[i];
                  final showDay =
                      i == 0 || !_sameDay(list[i - 1].sentAt, m.sentAt);
                  final mine =
                      m.senderId == me.id ||
                      (isAdmin && m.senderId == 'u-admin' && !participant);
                  return Column(
                    children: [
                      if (showDay) _DaySeparator(date: m.sentAt),
                      _Bubble(
                        message: m,
                        mine: mine,
                        senderLabel: chat.participantIds.length > 2 || isAdmin
                            ? participantName(m.senderId, users, restaurants)
                            : null,
                        onDelete: m.senderId == me.id
                            ? () => ref
                                  .read(
                                    chatMessagesProvider(
                                      widget.chatId,
                                    ).notifier,
                                  )
                                  .delete(m)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (me.role == UserRole.restaurant)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final reply in _quickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(reply, style: context.text.labelSmall),
                        onPressed: () => _send(chat, reply),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(chat),
                    decoration: InputDecoration(
                      hintText: isAdmin && !participant
                          ? 'Intervenir en tant que support…'
                          : 'Écrire un message…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Envoyer',
                  onPressed: () => _send(chat),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? "Aujourd'hui"
        : day == today.subtract(const Duration(days: 1))
        ? 'Hier'
        : Formatters.date(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: context.text.labelSmall),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    this.senderLabel,
    this.onDelete,
  });

  final Message message;
  final bool mine;
  final String? senderLabel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            m.text,
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine ? AppColors.primaryGradient : null,
        color: mine ? null : context.palette.surfaceMuted,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (senderLabel != null && !mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderLabel!,
                style: context.text.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            m.text,
            style: context.text.bodyMedium?.copyWith(
              color: mine ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${Formatters.time(m.sentAt)}${m.editedAt != null ? ' • modifié' : ''}',
                style: context.text.labelSmall?.copyWith(
                  color: mine ? Colors.white70 : context.palette.textSecondary,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(
                  switch (m.status) {
                    MessageStatus.sending => Icons.schedule_rounded,
                    MessageStatus.sent => Icons.check_rounded,
                    _ => Icons.done_all_rounded,
                  },
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onDelete == null
              ? null
              : () async {
                  final delete = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        title: const Text('Supprimer le message'),
                        onTap: () => Navigator.pop(context, true),
                      ),
                    ),
                  );
                  if (delete == true) onDelete!();
                },
          child: bubble,
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.2, end: 0);
  }
}

/// Trois points animés : l'autre participant écrit.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.palette.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: context.palette.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(
                    begin: 0,
                    end: -5,
                    delay: (150 * i).ms,
                    duration: 300.ms,
                  )
                  .then()
                  .moveY(begin: -5, end: 0, duration: 300.ms),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
