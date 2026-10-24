import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../catalog/data/catalog_mock_data.dart';
import '../../../data/communication_repositories.dart';
import '../../../data/mock/communication_mock_data.dart';
import '../../../data/reviews/review_repository.dart';
import '../../../models/review.dart';
import '../../widgets/reviews/photo_picker_sheet.dart';
import '../../widgets/reviews/rating_summary_card.dart';
import '../../widgets/reviews/star_rating.dart';

/// Formulaire d'avis : note globale (étoiles animées), notes par critère,
/// commentaire et photos. Sert à la création comme à la modification.
class WriteReviewPage extends StatefulWidget {
  const WriteReviewPage({
    super.key,
    this.restaurantId,
    this.orderId,
    this.reviewId,
  });

  final String? restaurantId;
  final String? orderId;

  /// Renseigné en mode modification.
  final String? reviewId;

  bool get isEditing => reviewId != null;

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  static const _maxComment = 500;

  final ReviewRepository _repository = CommunicationRepositories.reviews;
  final _comment = TextEditingController();

  late String? _restaurantId = widget.restaurantId;
  late String? _orderId = widget.orderId;
  int _rating = 0;
  final Map<ReviewCriterion, int> _criteria = {};
  List<String> _photos = [];
  bool _loading = false;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
    if (widget.isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final review = await _repository.fetchReview(widget.reviewId!);
      _comment.text = review.comment;
      setState(() {
        _restaurantId = review.restaurantId;
        _orderId = review.orderId;
        _rating = review.rating;
        _criteria.addAll(review.criteria);
        _photos = [...review.photos];
      });
    } on ApiException catch (e) {
      _loadError = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final result = await showPhotoPickerSheet(
      context,
      gallery: CommunicationMockData.photoGallery(_restaurantId!),
      selected: _photos,
    );
    if (result != null) setState(() => _photos = result);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final input = ReviewInput(
      restaurantId: _restaurantId!,
      orderId: _orderId,
      rating: _rating,
      // Un critère non noté reprend la note globale.
      criteria: {
        for (final c in ReviewCriterion.values) c: _criteria[c] ?? _rating,
      },
      comment: _comment.text.trim(),
      photos: _photos,
    );
    try {
      if (widget.isEditing) {
        await _repository.updateReview(widget.reviewId!, input);
      } else {
        await _repository.createReview(input);
      }
      if (!mounted) return;
      await _showSuccess();
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess() async {
    // showDialog s'ouvre sur le navigateur racine : c'est lui qu'il faut
    // dépiler (la page, elle, peut vivre dans le navigateur d'un onglet).
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                AppAssets.lottieSuccess,
                width: 140,
                height: 140,
                repeat: false,
              ),
              Text(
                widget.isEditing ? 'Avis modifié !' : 'Merci pour votre avis !',
                style: dialogContext.text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                widget.isEditing
                    ? 'Vos modifications sont enregistrées.'
                    : 'Il sera visible après validation par notre équipe.',
                textAlign: TextAlign.center,
                style: dialogContext.text.bodyMedium?.copyWith(
                  color: dialogContext.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton(icon: Icons.close_rounded)),
        title: Text(widget.isEditing ? "Modifier l'avis" : 'Votre avis'),
      ),
      body: _buildBody(context),
      bottomNavigationBar: _restaurantId == null || _loading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.sm,
                  AppSizes.pagePadding,
                  AppSizes.md,
                ),
                child: PrimaryButton(
                  label: widget.isEditing ? 'Enregistrer' : 'Publier mon avis',
                  icon: Icons.send_rounded,
                  isLoading: _submitting,
                  onPressed: _rating == 0 ? null : _submit,
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null || _restaurantId == null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Avis introuvable',
        message: _loadError ?? 'Aucun restaurant indiqué.',
      );
    }
    final restaurant = CatalogMockData.restaurantById(_restaurantId!);
    final (emoji, label) = ratingLabel(_rating);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      children:
          [
                // Restaurant concerné
                Row(
                  children: [
                    AppNetworkImage(
                      restaurant.imageUrl,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: context.text.titleMedium,
                          ),
                          Text(
                            _orderId == null
                                ? restaurant.cuisine
                                : 'Commande #$_orderId',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                // Note globale
                _Card(
                  child: Column(
                    children: [
                      Text(
                        'Comment était votre commande ?',
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(height: AppSizes.md),
                      AnimatedStarRating(
                        value: _rating,
                        size: 44,
                        semanticLabel: 'Note globale',
                        onChanged: (v) => setState(() => _rating = v),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: AppDurations.medium,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Text(
                          '$emoji  $label',
                          key: ValueKey(_rating),
                          style: context.text.titleSmall?.copyWith(
                            color: _rating == 0
                                ? context.palette.textSecondary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                // Notes séparées
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dans le détail', style: context.text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Facultatif : reprend la note globale par défaut',
                        style: context.text.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final criterion in ReviewCriterion.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                criterionIcon(criterion),
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  criterion.label,
                                  style: context.text.labelLarge,
                                ),
                              ),
                              AnimatedStarRating(
                                value: _criteria[criterion] ?? 0,
                                size: 24,
                                spacing: 4,
                                semanticLabel: criterion.label,
                                onChanged: (v) =>
                                    setState(() => _criteria[criterion] = v),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                // Commentaire
                AppTextField(
                  controller: _comment,
                  label: 'Votre commentaire',
                  hint: 'Qu\'avez-vous aimé ? Que pourrait-on améliorer ?',
                  maxLines: 5,
                  maxLength: _maxComment,
                  textCapitalization: TextCapitalization.sentences,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_comment.text.length}/$_maxComment',
                      style: context.text.labelSmall?.copyWith(
                        color: _comment.text.length > _maxComment * 0.9
                            ? AppColors.warning
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                // Photos
                Text(
                  'Photos (${_photos.length}/4)',
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 88,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_photos.length < 4) _AddPhotoTile(onTap: _pickPhotos),
                      for (final url in _photos)
                        Padding(
                          key: ValueKey(url),
                          padding: const EdgeInsets.only(left: 10),
                          child: _PhotoThumb(
                            url: url,
                            onRemove: () => setState(
                              () => _photos = [..._photos]..remove(url),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ]
              .animate(interval: 50.ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.08, end: 0),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: context.palette.softShadow,
      ),
      child: child,
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              'Ajouter',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AppNetworkImage(
                url,
                width: 88,
                height: 88,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                fallbackIcon: Icons.photo_rounded,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Pressable(
                  onTap: onRemove,
                  scale: 0.85,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .scaleXY(
          begin: 0.6,
          end: 1,
          duration: 350.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn();
  }
}
