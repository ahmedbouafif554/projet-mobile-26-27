import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/models/models.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import 'catalog_controllers.dart';
import 'product_form.dart';

/// Module 2 : produits de tous les restaurants (admin) ou « Mon menu »
/// (restaurateur), avec l'interrupteur disponible / rupture dans le tableau.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  /// Filtre rapide : null = tous, true = disponibles, false = en rupture.
  bool? _available;

  Future<void> _toggle(Product product, bool on) async {
    try {
      await ref
          .read(productsControllerProvider.notifier)
          .setAvailability(product, on);
      if (mounted) {
        AppSnackbar.success(
          context,
          on
              ? '${product.name} est de nouveau disponible'
              : '${product.name} est en rupture',
        );
      }
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurateur =
        ref.watch(authServiceProvider).role == UserRole.restaurant;
    final products = ref.watch(productsControllerProvider);
    final restaurants = ref.watch(restaurantsControllerProvider).value ?? [];
    final all = products.value ?? const <Product>[];
    final visible = _available == null
        ? products.value
        : all.where((p) => p.isAvailable == _available).toList();
    String restaurantName(String id) =>
        restaurants.where((r) => r.id == id).firstOrNull?.name ?? '—';

    final sections = {for (final p in all) p.section}.toList()..sort();

    return BoPage(
      title: isRestaurateur ? 'Mon menu' : 'Produits',
      subtitle: isRestaurateur
          ? 'Vos plats, prix et disponibilités en temps réel.'
          : 'Tous les produits des restaurants partenaires.',
      onAdd: () => openProductForm(context),
      addLabel: 'Nouveau produit',
      children: [
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            SummaryPill(
              label: 'Produits',
              value: all.length,
              color: AppColors.primary,
              icon: Icons.fastfood_rounded,
              selected: _available == null,
              onTap: () => setState(() => _available = null),
            ),
            SummaryPill(
              label: 'Disponibles',
              value: all.where((p) => p.isAvailable).length,
              color: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
              selected: _available == true,
              onTap: () => setState(() => _available = true),
            ),
            SummaryPill(
              label: 'En rupture',
              value: all.where((p) => !p.isAvailable).length,
              color: AppColors.error,
              icon: Icons.remove_shopping_cart_outlined,
              selected: _available == false,
              onTap: () => setState(() => _available = false),
            ),
          ],
        ),
        boGap,
        AppDataTable<Product>(
          items: visible,
          isLoading: products.isLoading,
          error: products.error,
          onRetry: () => ref.invalidate(productsControllerProvider),
          searchHint: 'Nom, description…',
          searchText: (p) =>
              '${p.name} ${p.description} ${restaurantName(p.restaurantId)}',
          filters: [
            AppTableFilter(
              label: 'Onglet',
              icon: Icons.restaurant_menu_rounded,
              options: {for (final s in sections) s: s},
              test: (p, v) => p.section == v,
            ),
            if (!isRestaurateur)
              AppTableFilter(
                label: 'Restaurant',
                icon: Icons.storefront_outlined,
                options: {for (final r in restaurants) r.id: r.name},
                test: (p, v) => p.restaurantId == v,
              ),
          ],
          columns: [
            AppTableColumn(
              label: 'Produit',
              primary: true,
              flex: 5,
              sortValue: (p) => p.name,
              cell: (context, p) => _ProductCell(product: p),
            ),
            if (!isRestaurateur)
              AppTableColumn(
                label: 'Restaurant',
                flex: 3,
                sortValue: (p) => restaurantName(p.restaurantId),
                cell: (context, p) => Text(
                  restaurantName(p.restaurantId),
                  style: context.text.bodySmall,
                ),
              ),
            AppTableColumn(
              label: 'Onglet',
              sortValue: (p) => p.section,
              cell: (context, p) =>
                  Text(p.section, style: context.text.bodySmall),
            ),
            AppTableColumn(
              label: 'Prix',
              numeric: true,
              sortValue: (p) => p.price,
              cell: (context, p) =>
                  Text(Formatters.price(p.price), style: context.text.titleSmall),
            ),
            AppTableColumn(
              label: 'Disponible',
              sortValue: (p) => p.isAvailable ? 1 : 0,
              cell: (context, p) => Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: p.isAvailable,
                  onChanged: (on) => _toggle(p, on),
                ),
              ),
            ),
          ],
          onEdit: (p) => openProductForm(context, product: p),
          onDelete: (p) =>
              ref.read(productsControllerProvider.notifier).remove(p.id),
          deleteMessage: (p) => '${p.name} sera retiré du menu.',
          actions: [
            AppTableAction(
              label: 'Marquer en rupture',
              icon: Icons.remove_shopping_cart_outlined,
              isVisible: (p) => p.isAvailable,
              onSelected: (p) => _toggle(p, false),
            ),
            AppTableAction(
              label: 'Remettre en vente',
              icon: Icons.add_shopping_cart_rounded,
              isVisible: (p) => !p.isAvailable,
              onSelected: (p) => _toggle(p, true),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductCell extends StatelessWidget {
  const _ProductCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Row(
      children: [
        AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: p.isAvailable ? 1 : 0.45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppNetworkImage(p.imageUrl, width: 48, height: 48),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (p.isPopular) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
              Text(
                p.isAvailable ? p.description : 'En rupture • ${p.description}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: p.isAvailable
                      ? context.palette.textSecondary
                      : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
