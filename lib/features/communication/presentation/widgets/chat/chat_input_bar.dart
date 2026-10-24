import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../models/chat_message.dart';

/// Zone de saisie du chat : messages rapides, bandeau de modification,
/// champ de texte et bouton d'envoi animé.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.quickReplies = const [],
    this.editing,
    this.onCancelEdit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final List<String> quickReplies;

  /// Message en cours de modification (null en mode envoi).
  final ChatMessage? editing;
  final VoidCallback? onCancelEdit;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _focusNode = FocusNode();

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Entrée en mode modification : on place le curseur dans le champ.
    if (widget.editing != null && oldWidget.editing?.id != widget.editing!.id) {
      _focusNode.requestFocus();
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_hasText) return;
    widget.onSend(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final showQuickReplies =
        editing == null && !_hasText && widget.quickReplies.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Messages rapides
            AnimatedSize(
              duration: AppDurations.medium,
              curve: Curves.easeOutCubic,
              child: showQuickReplies
                  ? SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.md,
                          10,
                          AppSizes.md,
                          2,
                        ),
                        itemCount: widget.quickReplies.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) =>
                            Pressable(
                                  onTap: () =>
                                      widget.onSend(widget.quickReplies[i]),
                                  scale: 0.92,
                                  haptic: true,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusLg,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      widget.quickReplies[i],
                                      style: context.text.labelLarge?.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                                .animate(delay: (50 * i).ms)
                                .fadeIn(duration: 250.ms)
                                .slideX(begin: 0.3, end: 0),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            // Bandeau « modification du message »
            AnimatedSize(
              duration: AppDurations.medium,
              curve: Curves.easeOutCubic,
              child: editing == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.fromLTRB(
                        AppSizes.md,
                        10,
                        AppSizes.md,
                        0,
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        border: const Border(
                          left: BorderSide(color: AppColors.primary, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Modifier le message',
                                  style: context.text.labelMedium?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  editing.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Annuler la modification',
                            onPressed: widget.onCancelEdit,
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                10,
                AppSizes.sm,
                10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: editing == null
                            ? 'Écrire un message…'
                            : 'Modifier…',
                        filled: true,
                        fillColor: context.palette.surfaceMuted,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusXl,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusXl,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusXl,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(
                    enabled: _hasText,
                    isEditing: editing != null,
                    onTap: _submit,
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

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.isEditing,
    required this.onTap,
  });

  final bool enabled;
  final bool isEditing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isEditing ? 'Enregistrer la modification' : 'Envoyer',
      child: Pressable(
        onTap: enabled ? onTap : null,
        scale: 0.85,
        haptic: true,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.primaryGradient : null,
            color: enabled ? null : context.palette.surfaceMuted,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: -0.2, end: 0.0).animate(animation),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              isEditing ? Icons.check_rounded : Icons.send_rounded,
              key: ValueKey('$isEditing-$enabled'),
              size: 21,
              color: enabled ? Colors.white : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
