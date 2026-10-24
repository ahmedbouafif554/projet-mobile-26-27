import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../models/chat_message.dart';

/// Icône du statut d'envoi (horloge, ✓, ✓✓, ✓✓ bleu, erreur).
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({
    super.key,
    required this.status,
    this.color,
    this.size = 15,
  });

  final MessageStatus status;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.palette.textSecondary;
    final (icon, tint, label) = switch (status) {
      MessageStatus.sending => (Icons.schedule_rounded, base, 'Envoi en cours'),
      MessageStatus.sent => (Icons.done_rounded, base, 'Envoyé'),
      MessageStatus.delivered => (Icons.done_all_rounded, base, 'Distribué'),
      MessageStatus.read => (Icons.done_all_rounded, AppColors.info, 'Lu'),
      MessageStatus.failed => (
        Icons.error_rounded,
        AppColors.error,
        "Échec de l'envoi",
      ),
    };
    return AnimatedSwitcher(
      duration: AppDurations.fast,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        icon,
        key: ValueKey(status),
        size: size,
        color: tint,
        semanticLabel: label,
      ),
    );
  }
}

/// Bulle de message : à droite (dégradé orange) pour l'utilisateur,
/// à gauche pour l'interlocuteur. Les nouveaux messages arrivent animés.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.animate = false,
    this.onLongPress,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;

  /// Joue l'animation d'apparition (messages arrivés pendant la session).
  final bool animate;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final deleted = message.isDeleted;
    final failed = message.status == MessageStatus.failed;
    final foreground = isMine && !deleted
        ? Colors.white
        : context.colors.onSurface;
    final meta = isMine && !deleted
        ? Colors.white.withValues(alpha: 0.8)
        : context.palette.textSecondary;
    const radius = Radius.circular(AppSizes.radiusLg);

    Widget bubble = GestureDetector(
      onLongPress: deleted ? null : onLongPress,
      onTap: failed ? onRetry : null,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          gradient: isMine && !deleted ? AppColors.primaryGradient : null,
          color: deleted
              ? context.palette.surfaceMuted
              : (isMine ? null : context.colors.surface),
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: isMine ? radius : const Radius.circular(6),
            bottomRight: isMine ? const Radius.circular(6) : radius,
          ),
          border: isMine || deleted
              ? null
              : Border.all(color: context.palette.border),
          boxShadow: deleted ? null : context.palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (deleted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 15, color: meta),
                  const SizedBox(width: 6),
                  Text(
                    'Message supprimé',
                    style: context.text.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: meta,
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(
                  message.text,
                  style: context.text.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isEdited)
                  Text(
                    'modifié • ',
                    style: context.text.labelSmall?.copyWith(color: meta),
                  ),
                Text(
                  Formatters.time(message.sentAt),
                  style: context.text.labelSmall?.copyWith(color: meta),
                ),
                if (isMine && !deleted) ...[
                  const SizedBox(width: 4),
                  MessageStatusIcon(
                    status: message.status,
                    color: meta,
                    size: 15,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (animate) {
      bubble = bubble
          .animate()
          .fadeIn(duration: 250.ms)
          .slideX(
            begin: isMine ? 0.25 : -0.25,
            end: 0,
            curve: Curves.easeOutCubic,
          )
          .scaleXY(
            begin: 0.85,
            end: 1,
            curve: Curves.easeOutBack,
            duration: 350.ms,
          );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          bubble,
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Échec de l\'envoi • touchez pour réessayer',
                style: context.text.labelSmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Séparateur de date entre les messages (« Aujourd'hui », « Hier »…).
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});

  final DateTime date;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    return Formatters.date(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_label, style: context.text.labelSmall),
        ),
      ),
    );
  }
}
