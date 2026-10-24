import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/avatar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/providers/chat_providers.dart';
import '../../../../router/front_routes.dart';
import '../../providers/communication_providers.dart';

/// Conversation : bulles animées, « en train d'écrire… », réponses rapides,
/// suppression d'un message (appui long).
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _markedRead = false;

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

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authServiceProvider).user;
    final chat = ref
        .watch(myChatsProvider)
        .value
        ?.where((c) => c.id == widget.chatId)
        .firstOrNull;
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final typing = ref.watch(chatTypingProvider(widget.chatId));

    ref.listen(chatMessagesProvider(widget.chatId), (prev, next) {
      if ((next.value?.length ?? 0) != (prev?.value?.length ?? 0)) {
        _scrollToEnd();
      }
    });
    ref.listen(chatTypingProvider(widget.chatId), (_, isTyping) {
      if (isTyping) _scrollToEnd();
    });

    if (me == null) return const Scaffold();
    if (chat == null) {
      return Scaffold(
        body: SafeArea(
          child: ref.watch(myChatsProvider).isLoading
              ? const Center(child: CircularProgressIndicator())
              : EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Conversation introuvable',
                  message: 'Elle a peut-être été supprimée.',
                  actionLabel: 'Retour',
                  onAction: () => context.go(FrontRoutes.messages),
                ),
        ),
      );
    }

    if (!_markedRead && chat.unreadCount > 0) {
      _markedRead = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(myChatsProvider.notifier).markRead(chat),
      );
    }

    final quickReplies = me.role == UserRole.courier
        ? const ['J’arrive dans 5 min', 'Je suis en bas', 'Merci, bonne journée !']
        : const ['Merci !', 'Où en est ma commande ?', 'Pouvez-vous sonner ?'];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Retour',
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(
                            me.role == UserRole.courier
                                ? FrontRoutes.courierMessages
                                : FrontRoutes.messages,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Avatar(name: chat.title, imageUrl: chat.avatarUrl, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                        AnimatedSwitcher(
                          duration: AppDurations.fast,
                          child: Text(
                            typing
                                ? 'En train d’écrire…'
                                : chat.isOnline
                                ? 'En ligne'
                                : chat.subtitle ?? chat.type.label,
                            key: ValueKey(typing),
                            style: context.text.labelSmall?.copyWith(
                              color: typing || chat.isOnline
                                  ? AppColors.success
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.call_rounded,
                    tooltip: 'Appeler',
                    onTap: () => AppSnackbar.info(
                      context,
                      'Appel de ${chat.title} (démo).',
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.palette.border),
            Expanded(
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) => list.isEmpty && !typing
                    ? const EmptyState(
                        compact: true,
                        icon: Icons.waving_hand_outlined,
                        title: 'Dites bonjour 👋',
                        message: 'Envoyez le premier message.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(AppSizes.md),
                        itemCount: list.length + (typing ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == list.length) return const _TypingDots();
                          final m = list[i];
                          final showDay =
                              i == 0 ||
                              !_sameDay(list[i - 1].sentAt, m.sentAt);
                          return Column(
                            children: [
                              if (showDay) _DayLabel(date: m.sentAt),
                              _Bubble(
                                message: m,
                                mine: m.senderId == me.id,
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
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final q in quickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => _send(chat, q),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(chat),
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message…',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Envoyer',
                      onPressed: () => _send(chat),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.date});

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
  const _Bubble({required this.message, required this.mine, this.onDelete});

  final Message message;
  final bool mine;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine ? AppColors.primaryGradient : null,
        color: mine ? null : context.colors.surface,
        boxShadow: mine ? null : context.palette.softShadow,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            m.text,
            style: context.text.bodyMedium?.copyWith(
              color: mine ? Colors.white : null,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.time(m.sentAt),
                style: context.text.labelSmall?.copyWith(
                  fontSize: 10,
                  color: mine ? Colors.white70 : context.palette.textSecondary,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 3),
                Icon(
                  switch (m.status) {
                    MessageStatus.sending => Icons.schedule_rounded,
                    MessageStatus.sent => Icons.check_rounded,
                    _ => Icons.done_all_rounded,
                  },
                  size: 13,
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
                    useRootNavigator: true,
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
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideX(begin: mine ? 0.15 : -0.15, end: 0, curve: Curves.easeOutCubic);
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: context.palette.softShadow,
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
                  .moveY(begin: 0, end: -5, delay: (150 * i).ms, duration: 300.ms)
                  .then()
                  .moveY(begin: -5, end: 0, duration: 300.ms),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
