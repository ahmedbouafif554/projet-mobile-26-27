import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../models/chat_message.dart';
import '../../../models/conversation.dart';
import '../../controllers/chat_room_controller.dart';
import '../../controllers/conversations_controller.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/quick_replies.dart';
import '../../widgets/chat/typing_indicator.dart';

/// Écran de conversation : bulles animées, statuts envoyé / lu,
/// « en train d'écrire », modification et suppression, messages rapides.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRoomController _room = ChatRoomController(
    widget.conversationId,
  );
  final _conversations = ConversationsController.instance;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _room.load();
    _conversations.load();
    // Après le premier rendu : la conversation devient « ouverte » (lue).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _conversations.setOpenConversation(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _conversations.setOpenConversation(null);
    _room.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    _input.clear();
    if (_room.editing != null) {
      final error = await _room.saveEdit(text);
      if (error != null && mounted) AppSnackbar.error(context, error);
    } else {
      await _room.send(text);
    }
  }

  void _cancelEdit() {
    _room.cancelEditing();
    _input.clear();
  }

  void _showActions(ChatMessage message) {
    final mine = message.isMine(_room.me);
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                0,
                AppSizes.pagePadding,
                8,
              ),
              child: Text(
                message.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copier'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: message.text));
                AppSnackbar.success(context, 'Message copié');
              },
            ),
            if (mine) ...[
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _room.startEditing(message);
                  _input
                    ..text = message.text
                    ..selection = TextSelection.collapsed(
                      offset: message.text.length,
                    );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Supprimer',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final error = await _room.delete(message);
                  if (error != null && mounted) {
                    AppSnackbar.error(context, error);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_room, _conversations]),
      builder: (context, _) {
        final conversation = _conversations.byId(widget.conversationId);
        return Scaffold(
          appBar: _ChatAppBar(
            conversation: conversation,
            isTyping: _room.isTyping,
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessages(context)),
              ChatInputBar(
                controller: _input,
                onSend: _send,
                editing: _room.editing,
                onCancelEdit: _cancelEdit,
                quickReplies: conversation == null
                    ? const []
                    : quickRepliesByType[conversation.type] ?? const [],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(BuildContext context) {
    if (_room.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_room.error != null && _room.messages.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Conversation indisponible',
        message: _room.error!,
        actionLabel: 'Réessayer',
        onAction: _room.load,
      );
    }

    // Liste inversée : l'élément 0 est en bas (dernier message).
    final items = <Widget>[];
    if (_room.isTyping) {
      items.add(
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: TypingIndicator(key: ValueKey('typing')),
          ),
        ),
      );
    }
    final messages = _room.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      items.add(
        MessageBubble(
          key: ValueKey(_room.keyOf(m)),
          message: m,
          isMine: m.isMine(_room.me),
          animate: _room.isFresh(m),
          onLongPress: () => _showActions(m),
          onRetry: () => _room.retry(m),
        ),
      );
      final isFirstOfDay =
          i == 0 || !_sameDay(messages[i - 1].sentAt, m.sentAt);
      if (isFirstOfDay) {
        items.add(DateSeparator(key: ValueKey('day-${m.id}'), date: m.sentAt));
      }
    }

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.waving_hand_rounded,
        title: 'Dites bonjour 👋',
        message: 'Envoyez un premier message ou choisissez une réponse rapide.',
      );
    }

    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.sm,
      ),
      children: items,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Barre du haut : avatar, nom et statut (« En ligne » / « écrit… »).
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.conversation, required this.isTyping});

  final Conversation? conversation;
  final bool isTyping;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  Future<void> _call(BuildContext context) async {
    final c = conversation;
    if (c == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.phone_in_talk_rounded,
          color: AppColors.success,
          size: 36,
        ),
        title: Text('Appeler ${c.title} ?'),
        content: const Text(
          'Votre numéro reste masqué pendant l\'appel (simulation).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Appeler'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppSnackbar.show(context, 'Appel en cours…', icon: Icons.phone_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final status = isTyping
        ? "En train d'écrire…"
        : c == null
        ? ''
        : c.isOnline
        ? 'En ligne'
        : c.type.label;

    return AppBar(
      toolbarHeight: kToolbarHeight + 8,
      leadingWidth: 68,
      leading: const Center(child: AppBackButton()),
      centerTitle: false,
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: AppNetworkImage(
                  c?.avatarUrl ?? '',
                  width: 42,
                  height: 42,
                  fallbackIcon: Icons.support_agent_rounded,
                ),
              ),
              if (c?.isOnline ?? false)
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
                        color: context.theme.scaffoldBackgroundColor,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c?.title ?? 'Conversation',
                  style: context.text.titleMedium,
                ),
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    status,
                    key: ValueKey(status),
                    style: context.text.labelSmall?.copyWith(
                      color: isTyping
                          ? AppColors.primary
                          : (c?.isOnline ?? false)
                          ? AppColors.success
                          : null,
                      fontStyle: isTyping ? FontStyle.italic : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (c != null && c.type != ConversationType.support)
          IconButton(
            tooltip: 'Appeler',
            onPressed: () => _call(context),
            icon: const Icon(Icons.phone_rounded, color: AppColors.success),
          ).animate().fadeIn(),
        const SizedBox(width: 8),
      ],
    );
  }
}
