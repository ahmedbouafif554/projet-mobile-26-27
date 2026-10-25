import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../shared/models/models.dart';
import '../../shell/bo_page.dart';
import 'catalog_controllers.dart';

/// Module 2 (admin) : catégories de cuisine, réordonnables par
/// glisser-déposer (ordre des pastilles sur l'accueil du front office).
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesControllerProvider);
    final restaurants = ref.watch(restaurantsControllerProvider).value ?? [];

    return BoPage(
      title: 'Catégories',
      subtitle:
          'Glissez-déposez pour changer l’ordre d’affichage dans l’application.',
      onAdd: () => showAppForm(context, const CategoryForm()),
      addLabel: 'Nouvelle catégorie',
      children: [
        AsyncValueView(
          value: categories,
          onRetry: () => ref.invalidate(categoriesControllerProvider),
          loading: ShimmerScope(
            child: Column(
              children: [
                for (var i = 0; i < 6; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SkeletonBox(height: 72, radius: AppSizes.radiusMd),
                  ),
              ],
            ),
          ),
          data: (list) => list.isEmpty
              ? AppCard(
                  child: EmptyState(
                    compact: true,
                    title: 'Aucune catégorie',
                    message: 'Créez la première catégorie de cuisine.',
                    actionLabel: 'Nouvelle catégorie',
                    onAction: () => showAppForm(context, const CategoryForm()),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: list.length,
                  onReorder: (from, to) => ref
                      .read(categoriesControllerProvider.notifier)
                      .move(from, to)
                      .catchError((Object e) {
                        if (context.mounted) AppSnackbar.error(context, e);
                      }),
                  proxyDecorator: (child, _, animation) => Material(
                    color: Colors.transparent,
                    elevation: 8,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final category = list[i];
                    return _CategoryTile(
                      key: ValueKey(category.id),
                      index: i,
                      category: category,
                      restaurantCount: restaurants
                          .where((r) => r.categoryIds.contains(category.id))
                          .length,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    super.key,
    required this.index,
    required this.category,
    required this.restaurantCount,
  });

  final int index;
  final Category category;
  final int restaurantCount;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Supprimer « ${category.name} » ?',
      message: restaurantCount == 0
          ? 'La catégorie sera supprimée définitivement.'
          : '$restaurantCount restaurant(s) ne seront plus classés dans cette catégorie.',
    );
    if (!confirmed) return;
    try {
      await ref.read(categoriesControllerProvider.notifier).remove(category.id);
      if (context.mounted) AppSnackbar.success(context, 'Catégorie supprimée');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                style: context.text.titleSmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(c.colorValue),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(c.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: context.text.titleSmall),
                  Text(
                    '$restaurantCount restaurant${restaurantCount > 1 ? 's' : ''}'
                    '${c.isActive ? '' : ' • masquée'}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: c.isActive ? 'Visible' : 'Masquée',
              child: Switch(
                value: c.isActive,
                onChanged: (on) => ref
                    .read(categoriesControllerProvider.notifier)
                    .save(c.copyWith(isActive: on), isNew: false),
              ),
            ),
            IconButton(
              tooltip: 'Modifier',
              onPressed: () => showAppForm(context, CategoryForm(category: c)),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: () => _delete(context, ref),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (40 * index).ms).fadeIn(duration: 300.ms).slideX(
      begin: 0.04,
      end: 0,
    );
  }
}

/// Création ([category] null) ou modification d'une catégorie.
class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({super.key, this.category});

  final Category? category;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<CategoryForm> {
  static const _colors = [
    0xFFFFE8D9,
    0xFFFFF4D6,
    0xFFE3F6E8,
    0xFFE1EEFF,
    0xFFF1E6FF,
    0xFFFFE1E8,
    0xFFE0F7F5,
    0xFFF0F0F3,
  ];
  static const _emojis = [
    '🍔', '🍕', '🍣', '🥗', '🍜', '🌮', '🍰', '🛒', '🥐', '🍗', '🥙', '☕',
  ];

  late final _name = TextEditingController(text: widget.category?.name);
  late String _emoji = widget.category?.emoji ?? _emojis.first;
  late int _color = widget.category?.colorValue ?? _colors.first;
  late bool _active = widget.category?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() {
    final list = ref.read(categoriesControllerProvider).value ?? [];
    final base =
        widget.category ??
        Category(id: '', name: '', emoji: _emoji, position: list.length);
    return ref
        .read(categoriesControllerProvider.notifier)
        .save(
          base.copyWith(
            name: _name.text.trim(),
            emoji: _emoji,
            colorValue: _color,
            isActive: _active,
          ),
          isNew: widget.category == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.category == null;
    return AppForm(
      title: isNew ? 'Nouvelle catégorie' : 'Modifier la catégorie',
      icon: Icons.category_rounded,
      successMessage: isNew ? 'Catégorie créée' : 'Catégorie mise à jour',
      onSubmit: _save,
      children: [
        Center(
          child: AnimatedContainer(
            duration: AppDurations.medium,
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color(_color),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(_emoji, style: const TextStyle(fontSize: 42)),
          ),
        ),
        AppTextField(
          controller: _name,
          label: 'Nom',
          hint: 'Burgers',
          validator: Validators.name,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Icône', style: context.text.labelLarge),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojis)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: e == _emoji,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Couleur', style: context.text.labelLarge),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == _color
                              ? AppColors.primary
                              : context.palette.border,
                          width: color == _color ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        AppSwitchField(
          title: 'Visible dans l’application',
          icon: Icons.visibility_outlined,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}
