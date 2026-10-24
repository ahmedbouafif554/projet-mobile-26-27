import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../catalog/presentation/widgets/catalog_shimmers.dart';
import '../../../communication_routes.dart';
import '../../controllers/conversations_controller.dart';
import '../../widgets/chat/conversation_tile.dart';

/// Liste des conversations (restaurants, livreur, support) avec non lus.
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _controller = ConversationsController.instance;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final unread = _controller.totalUnread;
        return Scaffold(
          appBar: AppBar(
            leadingWidth: 68,
            leading: const Center(child: AppBackButton()),
            title: Column(
              children: [
                const Text('Messages'),
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    unread == 0
                        ? 'Tout est lu'
                        : '$unread message${unread > 1 ? 's' : ''} non lu${unread > 1 ? 's' : ''}',
                    key: ValueKey(unread),
                    style: context.text.labelSmall?.copyWith(
                      color: unread == 0 ? null : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_controller.hasLoaded && _controller.error == null) {
      return const RestaurantListShimmer(count: 4);
    }
    if (!_controller.hasLoaded) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Chargement impossible',
        message: _controller.error!,
        actionLabel: 'Réessayer',
        onAction: () => _controller.load(force: true),
      );
    }
    final conversations = _controller.conversations;
    if (conversations.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Aucune conversation',
        message:
            'Vos échanges avec les restaurants et livreurs apparaîtront ici.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _controller.load(force: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        itemCount: conversations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = conversations[i];
          return ConversationTile(
                conversation: c,
                isTyping: _controller.isTyping(c.id),
                onTap: () => context.push(CommunicationRoutes.chat(c.id)),
              )
              .animate(key: ValueKey('conv-${c.id}'), delay: (60 * i).ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.15, end: 0);
        },
      ),
    );
  }
}
