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
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../providers/communication_providers.dart';

/// Conversations de l'utilisateur (client : compte › Messages ; livreur :
/// onglet Messages), avec accès au support.
class ChatsListPage extends ConsumerWidget {
  const ChatsListPage({super.key});

  Future<void> _openSupport(BuildContext context, WidgetRef ref) async {
    try {
      final chat = await ref.read(myChatsProvider.notifier).supportChat();
      if (context.mounted) context.push(_chatRoute(ref, chat.id));
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  static String _chatRoute(WidgetRef ref, String id) =>
      ref.read(authServiceProvider).role == UserRole.courier
      ? FrontRoutes.courierChat(id)
      : FrontRoutes.chat(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(myChatsProvider);
    final list = chats.value ?? const <Chat>[];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.sm,
                AppSizes.sm,
              ),
              child: Row(
                children: [
                  const Expanded(child: PageTitle('Messages')),
                  IconButton(
                    tooltip: 'Contacter le support',
                    onPressed: () => _openSupport(context, ref),
                    icon: const Icon(Icons.support_agent_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: chats.isLoading && chats.value == null
                  ? ShimmerScope(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSizes.pagePadding),
                        children: [
                          for (var i = 0; i < 4; i++)
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppSizes.md),
                              child: SkeletonBox(height: 64),
                            ),
                        ],
                      ),
                    )
                  : list.isEmpty
                  ? EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'Aucune conversation',
                      message: 'Une question ? Notre support répond 7j/7.',
                      actionLabel: 'Contacter le support',
                      onAction: () => _openSupport(context, ref),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        ref.invalidate(myChatsProvider);
                        await ref.read(myChatsProvider.future);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          AppSizes.sm,
                          AppSizes.pagePadding,
                          AppSizes.xl,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: context.palette.border),
                        itemBuilder: (context, i) => _ChatTile(
                          chat: list[i],
                          onTap: () => context.push(_chatRoute(ref, list[i].id)),
                        ).animate(delay: (40 * i).ms).fadeIn().slideX(begin: 0.04),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Avatar(name: chat.title, imageUrl: chat.avatarUrl, size: 52),
                if (chat.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 13,
                      height: 13,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: unread ? FontWeight.w700 : null,
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
                  if (chat.subtitle != null)
                    Text(
                      chat.subtitle!,
                      style: context.text.labelSmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? 'Démarrer la conversation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: unread
                                ? context.colors.onSurface
                                : context.palette.textSecondary,
                            fontWeight: unread ? FontWeight.w600 : null,
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
    );
  }
}
