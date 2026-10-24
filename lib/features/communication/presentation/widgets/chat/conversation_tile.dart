import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../models/conversation.dart';
import 'message_bubble.dart';

/// Ligne de la liste des conversations : avatar (pastille « en ligne »),
/// dernier message ou « écrit… », heure et compteur de non lus animé.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.isTyping,
    required this.onTap,
  });

  final Conversation conversation;
  final bool isTyping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.unreadCount > 0;
    final mine = last != null && last.isMine(AppConfig.currentUserId);
    final preview = last == null
        ? 'Démarrer la conversation'
        : last.isDeleted
        ? 'Message supprimé'
        : '${mine ? 'Vous : ' : ''}${last.text}';

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(
                  alpha: context.isDark ? 0.10 : 0.04,
                )
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: unread
                ? AppColors.primary.withValues(alpha: 0.25)
                : context.palette.border,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: AppNetworkImage(
                    c.avatarUrl ?? '',
                    width: 52,
                    height: 52,
                    fallbackIcon: Icons.support_agent_rounded,
                  ),
                ),
                if (c.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.surface,
                          width: 2.5,
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
                          c.title,
                          style: context.text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        last == null ? '' : _time(last.sentAt),
                        style: context.text.labelSmall?.copyWith(
                          color: unread ? AppColors.primary : null,
                        ),
                      ),
                    ],
                  ),
                  if (c.subtitle != null)
                    Text(
                      '${c.type.label} • ${c.subtitle}',
                      style: context.text.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (last != null &&
                          mine &&
                          !isTyping &&
                          !last.isDeleted) ...[
                        MessageStatusIcon(status: last.status, size: 15),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppDurations.fast,
                          // Aperçu aligné à gauche (AnimatedSwitcher centre par défaut).
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          child: Text(
                            isTyping ? "En train d'écrire…" : preview,
                            key: ValueKey(isTyping ? 'typing' : preview),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: isTyping
                                  ? AppColors.primary
                                  : unread
                                  ? context.colors.onSurface
                                  : null,
                              fontWeight: unread ? FontWeight.w600 : null,
                              fontStyle: isTyping ? FontStyle.italic : null,
                            ),
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                '${c.unreadCount}',
                                style: context.text.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .animate(key: ValueKey(c.unreadCount))
                            .scaleXY(
                              begin: 0.3,
                              end: 1,
                              duration: 550.ms,
                              curve: Curves.elasticOut,
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

  String _time(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return sameDay ? Formatters.time(date) : Formatters.relative(date);
  }
}
