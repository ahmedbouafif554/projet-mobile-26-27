import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../../orders/providers/cart_controller.dart';

/// Ouvre la fiche d'un plat (options, quantité, note) en feuille modale.
Future<void> showProductSheet(BuildContext context, Product product) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => ProductSheet(product: product),
    );

class ProductSheet extends ConsumerStatefulWidget {
  const ProductSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  late final Map<String, Set<ProductOption>> _choices = {
    for (final g in widget.product.optionGroups)
      // Un choix obligatoire unique est présélectionné.
      g.id: g.isRequired && !g.isMultiple && g.options.isNotEmpty
          ? {g.options.first}
          : <ProductOption>{},
  };
  final _note = TextEditingController();
  int _quantity = 1;
  bool _adding = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<ProductOption> get _options => [
    for (final g in widget.product.optionGroups) ...?_choices[g.id],
  ];

  double get _unitPrice =>
      widget.product.price + _options.fold<double>(0, (s, o) => s + o.price);

  ProductOptionGroup? get _missing => widget.product.optionGroups
      .where((g) => g.isRequired && (_choices[g.id]?.isEmpty ?? true))
      .firstOrNull;

  void _toggle(ProductOptionGroup group, ProductOption option) {
    setState(() {
      final selected = _choices[group.id]!;
      if (!group.isMultiple) {
        selected
          ..clear()
          ..add(option);
      } else if (selected.contains(option)) {
        selected.remove(option);
      } else if (selected.length < group.maxChoices) {
        selected.add(option);
      } else {
        AppSnackbar.info(
          context,
          '${group.maxChoices} choix maximum pour « ${group.name} ».',
        );
      }
    });
  }

  Future<void> _add() async {
    final missing = _missing;
    if (missing != null) {
      AppSnackbar.info(context, 'Choisissez : ${missing.name}');
      return;
    }
    final cart = ref.read(cartProvider.notifier);
    await ref.read(cartProvider.future);
    if (!mounted) return;
    if (cart.conflictsWith(widget.product)) {
      final replace = await ConfirmDeleteDialog.show(
        context,
        title: 'Commencer un nouveau panier ?',
        message:
            'Votre panier contient des plats d’un autre restaurant. Il sera vidé.',
        confirmLabel: 'Nouveau panier',
        icon: Icons.remove_shopping_cart_outlined,
      );
      if (!replace) return;
      await cart.clear();
    }
    setState(() => _adding = true);
    try {
      await cart.add(
        widget.product,
        quantity: _quantity,
        options: _options,
        note: _note.text,
      );
      if (!mounted) return;
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${widget.product.name} ajouté au panier'),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => router.go(FrontRoutes.cart),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _adding = false);
        AppSnackbar.error(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      AppNetworkImage(
                        p.imageUrl,
                        height: 220,
                        width: double.infinity,
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Fermer',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          [
                                Text(p.name, style: context.text.headlineSmall),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      Formatters.price(p.price),
                                      style: context.text.titleMedium?.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (p.calories != null) ...[
                                      const SizedBox(width: 12),
                                      InfoTag(
                                        icon: Icons.local_fire_department_outlined,
                                        label: '${p.calories} kcal',
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSizes.sm),
                                Text(
                                  p.description,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                                for (final group in p.optionGroups) ...[
                                  const SizedBox(height: AppSizes.lg),
                                  _GroupHeader(group: group),
                                  const SizedBox(height: AppSizes.sm),
                                  for (final option in group.options)
                                    _OptionTile(
                                      option: option,
                                      multiple: group.isMultiple,
                                      selected: _choices[group.id]!.contains(
                                        option,
                                      ),
                                      onTap: () => _toggle(group, option),
                                    ),
                                ],
                                const SizedBox(height: AppSizes.lg),
                                Text(
                                  'Instructions spéciales',
                                  style: context.text.titleSmall,
                                ),
                                const SizedBox(height: AppSizes.sm),
                                TextField(
                                  controller: _note,
                                  maxLength: 120,
                                  decoration: const InputDecoration(
                                    hintText: 'Sans oignons, bien cuit…',
                                  ),
                                ),
                              ]
                              .animate(interval: 30.ms)
                              .fadeIn(duration: 250.ms)
                              .slideY(begin: 0.05, end: 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              boxShadow: [
                BoxShadow(
                  color: context.palette.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.sm + 4,
                  AppSizes.pagePadding,
                  AppSizes.sm + 4,
                ),
                child: Row(
                  children: [
                    QuantityStepper(
                      value: _quantity,
                      onChanged: (q) => setState(() => _quantity = q),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Ajouter',
                        isLoading: _adding,
                        onPressed: _add,
                        trailing: Text(
                          Formatters.price(_unitPrice * _quantity),
                          style: context.text.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final ProductOptionGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(group.name, style: context.text.titleMedium)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: group.isRequired
                ? AppColors.primary.withValues(alpha: 0.12)
                : context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            group.isRequired
                ? 'Obligatoire'
                : group.isMultiple
                ? '${group.maxChoices} max'
                : 'Facultatif',
            style: context.text.labelSmall?.copyWith(
              color: group.isRequired
                  ? AppColors.primary
                  : context.palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.multiple,
    required this.selected,
    required this.onTap,
  });

  final ProductOption option;
  final bool multiple;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: selected ? AppColors.primary : context.palette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              multiple
                  ? (selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded)
                  : (selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded),
              color: selected
                  ? AppColors.primary
                  : context.palette.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(option.name, style: context.text.bodyMedium)),
            if (option.price > 0)
              Text(
                '+ ${Formatters.price(option.price)}',
                style: context.text.labelLarge?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
