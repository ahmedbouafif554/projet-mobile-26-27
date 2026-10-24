import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../catalog/presentation/widgets/catalog_shimmers.dart';
import '../../../models/review.dart';
import '../../controllers/review_moderation_controller.dart';
import '../../widgets/reviews/review_card.dart';

/// Modération des avis (admin) : approuver, refuser, ignorer les
/// signalements et répondre au nom du restaurant.
class ReviewModerationPage extends StatefulWidget {
  const ReviewModerationPage({super.key});

  @override
  State<ReviewModerationPage> createState() => _ReviewModerationPageState();
}

class _ReviewModerationPageState extends State<ReviewModerationPage> {
  late final ReviewModerationController _controller =
      ReviewModerationController()..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _moderate(Review review, ReviewStatus status) async {
    final error = await _controller.moderate(review, status);
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(
        context,
        status == ReviewStatus.approved ? 'Avis publié' : 'Avis masqué',
      );
    }
  }

  Future<void> _reply(Review review) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReplySheet(review: review),
    );
    if (message == null) return;
    final error = await _controller.reply(review, message);
    if (!mounted) return;
    error == null
        ? AppSnackbar.success(context, 'Réponse publiée')
        : AppSnackbar.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Modération des avis'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  4,
                  AppSizes.pagePadding,
                  4,
                ),
                children: [
                  for (final tab in ModerationTab.values) ...[
                    SelectableChip(
                      label: _controller.isLoading
                          ? tab.label
                          : '${tab.label} (${_controller.countOf(tab)})',
                      selected: _controller.tab == tab,
                      onTap: () => _controller.selectTab(tab),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_controller.isLoading) return const RestaurantListShimmer(count: 3);
    if (_controller.error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Chargement impossible',
        message: _controller.error!,
        actionLabel: 'Réessayer',
        onAction: _controller.load,
      );
    }
    final reviews = _controller.visible;
    if (reviews.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'Rien à traiter',
        message: 'Tous les avis de cette catégorie ont été traités 👏',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final review = reviews[i];
        return ReviewCard(
              review: review,
              heroOrigin: 'moderation-${_controller.tab.name}',
              showRestaurant: true,
              showStatus: true,
              footer: _ModerationActions(
                review: review,
                tab: _controller.tab,
                onModerate: (status) => _moderate(review, status),
                onReply: review.reply == null ? () => _reply(review) : null,
              ),
            )
            .animate(
              key: ValueKey('mod-${_controller.tab.name}-${review.id}'),
              delay: (60 * i.clamp(0, 5)).ms,
            )
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.12, end: 0)
            // Sortie animée une fois l'avis traité.
            .animate(target: _controller.isLeaving(review) ? 1 : 0)
            .fadeOut(duration: ReviewModerationController.leaveDuration)
            .slideX(
              begin: 0,
              end: 0.35,
              duration: ReviewModerationController.leaveDuration,
            );
      },
    );
  }
}

class _ModerationActions extends StatelessWidget {
  const _ModerationActions({
    required this.review,
    required this.tab,
    required this.onModerate,
    this.onReply,
  });

  final Review review;
  final ModerationTab tab;
  final ValueChanged<ReviewStatus> onModerate;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: context.text.labelLarge,
    );

    final (approveLabel, rejectLabel) = switch (tab) {
      ModerationTab.pending => ('Approuver', 'Refuser'),
      ModerationTab.reported => ('Conserver', 'Masquer'),
      ModerationTab.rejected => ('Rétablir', null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tab == ModerationTab.reported)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  'Signalé ${review.reportCount} fois',
                  style: context.text.labelMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        if (onReply != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: const Text('Répondre au nom du restaurant'),
            ),
          ),
        Row(
          children: [
            if (rejectLabel != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onModerate(ReviewStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    textStyle: context.text.labelLarge,
                  ),
                  child: Text(rejectLabel),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                onPressed: () => onModerate(ReviewStatus.approved),
                style: buttonStyle.copyWith(
                  backgroundColor: const WidgetStatePropertyAll(
                    AppColors.success,
                  ),
                ),
                child: Text(approveLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Saisie de la réponse du restaurant.
class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.review});

  final Review review;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Répondre à ${widget.review.authorName}',
                style: context.text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '« ${widget.review.comment} »',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSizes.md),
              AppTextField(
                controller: _message,
                label: 'Réponse publique du restaurant',
                hint: 'Merci pour votre retour…',
                maxLines: 4,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => Validators.required(v, field: 'La réponse'),
              ),
              const SizedBox(height: AppSizes.md),
              PrimaryButton(
                label: 'Publier la réponse',
                icon: Icons.send_rounded,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, _message.text.trim());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
