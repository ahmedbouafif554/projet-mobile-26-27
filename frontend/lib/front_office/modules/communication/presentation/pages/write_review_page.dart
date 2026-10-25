import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../orders/providers/orders_providers.dart';
import '../../providers/communication_providers.dart';

/// Écrire (ou modifier) l'avis d'une commande livrée : note globale animée,
/// notes détaillées, mots-clés, commentaire et photos.
class WriteReviewPage extends ConsumerWidget {
  const WriteReviewPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    final existing = ref
        .watch(myReviewsProvider)
        .value
        ?.where((r) => r.orderId == orderId)
        .firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: order,
          onRetry: () => ref.invalidate(orderProvider(orderId)),
          data: (o) => _ReviewForm(order: o, existing: existing),
        ),
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.order, this.existing});

  final Order order;
  final Review? existing;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late int _rating = widget.existing?.rating ?? 0;
  late int _food = widget.existing?.foodRating ?? 0;
  late int _delivery = widget.existing?.deliveryRating ?? 0;
  late int _packaging = widget.existing?.packagingRating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  late final Set<String> _photos = {...?widget.existing?.photos};
  bool _saving = false;

  static const _labels = ['', 'Décevant 😞', 'Moyen 😐', 'Bien 🙂', 'Très bien 😋', 'Excellent ! 🤩'];
  static const _tags = [
    'Délicieux',
    'Bien chaud',
    'Copieux',
    'Livraison rapide',
    'Livreur sympa',
    'Bon emballage',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppSnackbar.info(context, 'Choisissez une note de 1 à 5 étoiles.');
      return;
    }
    final user = ref.read(authServiceProvider).user!;
    setState(() => _saving = true);
    final base =
        widget.existing ??
        Review(
          id: '',
          restaurantId: widget.order.restaurantId,
          userId: user.id,
          userName: '${user.firstName} ${user.lastName.isEmpty ? '' : '${user.lastName[0]}.'}',
          userAvatar: user.avatarUrl,
          orderId: widget.order.id,
          rating: _rating,
          createdAt: DateTime.now(),
        );
    try {
      await ref
          .read(myReviewsProvider.notifier)
          .save(
            base.copyWith(
              rating: _rating,
              foodRating: _food == 0 ? null : _food,
              deliveryRating: _delivery == 0 ? null : _delivery,
              packagingRating: _packaging == 0 ? null : _packaging,
              comment: _comment.text.trim(),
              photos: _photos.toList(),
            ),
          );
      if (!mounted) return;
      AppSnackbar.success(
        context,
        'Merci pour votre avis ! Il sera publié après vérification.',
      );
      context.canPop() ? context.pop() : context.go(FrontRoutes.orders);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackbar.error(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final photos = {for (final item in o.items) item.product.imageUrl}.toList();
    Widget subRating(String label, int value, ValueChanged<int> onChanged) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: context.text.bodyMedium)),
              StarRatingInput(value: value, onChanged: onChanged, size: 28),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      children:
          [
                PageTitle(widget.existing == null ? 'Votre avis' : 'Modifier mon avis'),
                const SizedBox(height: AppSizes.lg),
                Text(
                  o.restaurantName,
                  textAlign: TextAlign.center,
                  style: context.text.headlineSmall,
                ),
                Text(
                  'Commande #${o.reference}',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Center(
                  child: StarRatingInput(
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    _rating == 0 ? 'Touchez une étoile' : _labels[_rating],
                    key: ValueKey(_rating),
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium?.copyWith(
                      color: _rating == 0
                          ? context.palette.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    boxShadow: context.palette.softShadow,
                  ),
                  child: Column(
                    children: [
                      subRating('Plats', _food, (v) => setState(() => _food = v)),
                      subRating(
                        'Livraison',
                        _delivery,
                        (v) => setState(() => _delivery = v),
                      ),
                      subRating(
                        'Emballage',
                        _packaging,
                        (v) => setState(() => _packaging = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    for (final tag in _tags)
                      ActionChip(
                        label: Text(tag),
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        onPressed: () {
                          final text = _comment.text.trim();
                          if (text.contains(tag)) return;
                          _comment.text = text.isEmpty ? tag : '$text, ${tag.toLowerCase()}';
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Racontez-nous votre expérience…',
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Text('Ajouter des photos', style: context.text.titleSmall),
                const SizedBox(height: AppSizes.sm),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final selected = _photos.contains(photos[i]);
                      return GestureDetector(
                        onTap: () => setState(
                          () => selected
                              ? _photos.remove(photos[i])
                              : _photos.add(photos[i]),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: AppDurations.fast,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusSm,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AppNetworkImage(
                                  photos[i],
                                  width: 78,
                                  height: 78,
                                ),
                              ),
                            ),
                            if (selected)
                              const Positioned(
                                right: 4,
                                top: 4,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: AppColors.primary,
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                PrimaryButton(
                  label: widget.existing == null ? 'Publier mon avis' : 'Enregistrer',
                  icon: Icons.send_rounded,
                  isLoading: _saving,
                  onPressed: _submit,
                ),
              ]
              .animate(interval: 40.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.05, end: 0),
    );
  }
}
