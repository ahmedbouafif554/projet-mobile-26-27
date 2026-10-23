import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_price.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/info_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/quantity_selector.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../../orders/models/cart_item.dart';
import '../../../orders/presentation/controllers/cart_controller.dart';
import '../../../orders/presentation/widgets/cart_badge_button.dart';
import '../../data/catalog_mock_data.dart';
import '../../models/product.dart';

/// Détail d'un produit : options (taille, suppléments), quantité,
/// remarque et bouton « Ajouter au panier » animé.
class ProductPage extends StatefulWidget {
  const ProductPage({
    super.key,
    required this.productId,
    required this.heroOrigin,
  });

  final String productId;
  final String heroOrigin;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final Product _product = CatalogMockData.productById(widget.productId);
  final _note = TextEditingController();

  /// Option choisie pour chaque groupe à choix unique.
  final Map<String, ProductOption> _singleChoices = {};

  /// Options cochées (groupes à choix multiple).
  final Set<ProductOption> _extras = {};
  int _quantity = 1;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    // Pré-sélectionne la première option des groupes obligatoires.
    for (final group in _product.optionGroups) {
      if (!group.allowMultiple && group.options.isNotEmpty) {
        _singleChoices[group.id] = group.options.first;
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _unitPrice =>
      _product.price +
      _singleChoices.values.fold<double>(0, (s, o) => s + o.extraPrice) +
      _extras.fold<double>(0, (s, o) => s + o.extraPrice);

  double get _total => _unitPrice * _quantity;

  Future<void> _addToCart() async {
    if (_added) return;
    final note = _note.text.trim();
    CartController.instance.add(
      CartItem(
        product: _product,
        size: _singleChoices.values.isEmpty
            ? null
            : _singleChoices.values.first,
        extras: _extras.toList(),
        quantity: _quantity,
        note: note.isEmpty ? null : note,
      ),
    );
    HapticFeedback.mediumImpact();
    setState(() => _added = true);

    final router = GoRouter.of(context);
    AppSnackbar.success(
      context,
      '${_product.name} ajouté au panier',
      actionLabel: 'Voir',
      onAction: () => router.push(AppRoutes.cart),
    );

    // Laisse le temps d'apprécier l'animation, puis revient au menu.
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      setState(() => _added = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final restaurant = CatalogMockData.restaurantById(p.restaurantId);
    final background = context.theme.scaffoldBackgroundColor;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            automaticallyImplyLeading: false,
            backgroundColor: background,
            leadingWidth: 68,
            leading: const Center(child: AppBackButton(elevated: true)),
            actions: const [
              CartBadgeButton(elevated: true),
              SizedBox(width: AppSizes.md),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Hero(
                tag: HeroTags.product(p.id, widget.heroOrigin),
                child: AppNetworkImage(
                  p.imageUrl,
                  fallbackIcon: Icons.fastfood_rounded,
                ),
              ),
            ),
            // Bord arrondi qui « recouvre » le bas de l'image.
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSizes.radiusXl + 4),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              0,
              AppSizes.pagePadding,
              AppSizes.xl,
            ),
            sliver: SliverList.list(
              children:
                  [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: context.text.headlineSmall,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              Formatters.price(p.price),
                              style: context.text.headlineSmall?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restaurant.name,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            InfoChip(
                              icon: Icons.star_rounded,
                              iconColor: context.palette.warning,
                              label: restaurant.rating
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ','),
                            ),
                            InfoChip(
                              icon: Icons.schedule_rounded,
                              label: restaurant.deliveryTimeLabel,
                            ),
                            if (p.calories != null)
                              InfoChip(
                                icon: Icons.local_fire_department_rounded,
                                iconColor: AppColors.primary,
                                label: '${p.calories} kcal',
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          p.description,
                          style: context.text.bodyLarge?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        for (final group in p.optionGroups)
                          _buildGroup(context, group),
                        Text('Une remarque ?', style: context.text.titleMedium),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: _note,
                          hint: 'Ex. : sans oignons, sauce à part…',
                          prefixIcon: Icons.edit_note_rounded,
                          maxLines: 2,
                        ),
                      ]
                      .animate(interval: 40.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AddToCartBar(
        quantity: _quantity,
        total: _total,
        added: _added,
        onQuantityChanged: (q) => setState(() => _quantity = q),
        onAdd: _addToCart,
      ),
    );
  }

  Widget _buildGroup(BuildContext context, ProductOptionGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.title, style: context.text.titleMedium),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: group.isRequired
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : context.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  group.isRequired ? 'Obligatoire' : 'Facultatif',
                  style: context.text.labelSmall?.copyWith(
                    color: group.isRequired ? AppColors.primary : null,
                  ),
                ),
              ),
            ],
          ),
          if (group.allowMultiple)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Plusieurs choix possibles',
                style: context.text.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          for (final option in group.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableTile(
                title: option.name,
                multiple: group.allowMultiple,
                selected: group.allowMultiple
                    ? _extras.contains(option)
                    : _singleChoices[group.id] == option,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.extraPrice > 0
                          ? '+ ${Formatters.price(option.extraPrice)}'
                          : 'Inclus',
                      style: context.text.labelLarge?.copyWith(
                        color: option.extraPrice > 0
                            ? context.colors.onSurface
                            : context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    group.allowMultiple
                        ? CheckDot(selected: _extras.contains(option))
                        : RadioDot(
                            selected: _singleChoices[group.id] == option,
                          ),
                  ],
                ),
                onTap: () => setState(() {
                  if (group.allowMultiple) {
                    _extras.contains(option)
                        ? _extras.remove(option)
                        : _extras.add(option);
                  } else {
                    _singleChoices[group.id] = option;
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barre du bas : quantité + bouton d'ajout avec le prix total animé.
class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.quantity,
    required this.total,
    required this.added,
    required this.onQuantityChanged,
    required this.onAdd,
  });

  final int quantity;
  final double total;
  final bool added;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              QuantitySelector(value: quantity, onChanged: onQuantityChanged),
              const SizedBox(width: 12),
              Expanded(
                child:
                    PrimaryButton(
                          label: added ? 'Ajouté !' : 'Ajouter',
                          icon: added
                              ? Icons.check_circle_rounded
                              : Icons.shopping_bag_outlined,
                          color: added ? AppColors.success : null,
                          onPressed: onAdd,
                          trailing: added
                              ? null
                              : AnimatedPrice(
                                  total,
                                  style: context.text.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                        )
                        // Petit « pop » + reflet lumineux au moment de l'ajout.
                        .animate(target: added ? 1 : 0)
                        .scaleXY(
                          begin: 1,
                          end: 1.04,
                          duration: 180.ms,
                          curve: Curves.easeOut,
                        )
                        .shimmer(
                          duration: 700.ms,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
