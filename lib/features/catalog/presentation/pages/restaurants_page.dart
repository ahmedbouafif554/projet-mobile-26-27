import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../orders/presentation/widgets/cart_badge_button.dart';
import '../../data/catalog_mock_data.dart';
import '../../models/restaurant.dart';
import '../widgets/catalog_shimmers.dart';
import '../widgets/restaurant_tile.dart';

/// Filtres rapides disponibles sur la liste.
enum _QuickFilter { topRated, freeDelivery, promo, fast }

extension on _QuickFilter {
  String get label => switch (this) {
    _QuickFilter.topRated => 'Note 4,7+',
    _QuickFilter.freeDelivery => 'Livraison offerte',
    _QuickFilter.promo => 'Promos',
    _QuickFilter.fast => '< 30 min',
  };

  IconData get icon => switch (this) {
    _QuickFilter.topRated => Icons.star_rounded,
    _QuickFilter.freeDelivery => Icons.delivery_dining_rounded,
    _QuickFilter.promo => Icons.local_offer_rounded,
    _QuickFilter.fast => Icons.bolt_rounded,
  };

  bool matches(Restaurant r) => switch (this) {
    _QuickFilter.topRated => r.rating >= 4.7,
    _QuickFilter.freeDelivery => r.hasFreeDelivery,
    _QuickFilter.promo => r.promo != null,
    _QuickFilter.fast => r.deliveryMinutes <= 25,
  };
}

/// Ordre de tri de la liste.
enum _Sort { recommended, nearest, rating, fastest }

extension on _Sort {
  String get label => switch (this) {
    _Sort.recommended => 'Recommandés',
    _Sort.nearest => 'Les plus proches',
    _Sort.rating => 'Les mieux notés',
    _Sort.fastest => 'Les plus rapides',
  };
}

/// Liste des restaurants avec recherche, catégories, filtres et tri.
class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key, this.categoryId, this.filter});

  /// Catégorie présélectionnée (ex. : « courses »).
  final String? categoryId;

  /// Filtre d'entrée : « popular » ou « nearby ».
  final String? filter;

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  // Une catégorie vide ou inconnue (lien mal formé) équivaut à « Tous ».
  late String? _categoryId = CatalogMockData.categoryById(
    widget.categoryId,
  )?.id;
  late _Sort _sort = widget.filter == 'nearby'
      ? _Sort.nearest
      : _Sort.recommended;
  late bool _popularOnly = widget.filter == 'popular';
  final Set<_QuickFilter> _filters = {};
  String _query = '';
  bool _loading = true;

  /// Clé de la puce de catégorie sélectionnée (pour la faire défiler en vue).
  final _selectedChipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
    // Catégorie présélectionnée : on amène sa puce à l'écran.
    if (widget.categoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chipContext = _selectedChipKey.currentContext;
        if (chipContext != null) {
          Scrollable.ensureVisible(
            chipContext,
            alignment: 0.5,
            duration: AppDurations.slow,
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  String get _title {
    if (_popularOnly) return 'Populaires';
    if (widget.filter == 'nearby' && _categoryId == null) {
      return 'Près de chez vous';
    }
    return CatalogMockData.categoryById(_categoryId)?.name ?? 'Restaurants';
  }

  List<Restaurant> get _results {
    final q = _query.toLowerCase();
    final list = CatalogMockData.restaurants.where((r) {
      if (_categoryId != null && r.categoryId != _categoryId) return false;
      if (_popularOnly && !r.isPopular) return false;
      if (q.isNotEmpty &&
          !r.name.toLowerCase().contains(q) &&
          !r.cuisine.toLowerCase().contains(q)) {
        return false;
      }
      return _filters.every((f) => f.matches(r));
    }).toList();

    switch (_sort) {
      case _Sort.recommended:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      case _Sort.nearest:
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      case _Sort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _Sort.fastest:
        list.sort((a, b) => a.deliveryMinutes.compareTo(b.deliveryMinutes));
    }
    return list;
  }

  void _resetFilters() => setState(() {
    _categoryId = null;
    _popularOnly = false;
    _filters.clear();
    _query = '';
  });

  @override
  Widget build(BuildContext context) {
    final results = _results;
    // Clé dépendant des filtres : la liste est rejouée (cascade) à chaque changement.
    final listKey = ValueKey(
      '$_categoryId-$_popularOnly-$_filters-$_sort-$_query',
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.sm,
                AppSizes.pagePadding,
                0,
              ),
              child: Row(
                children: [
                  const AppBackButton(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppDurations.fast,
                      child: Text(
                        _title,
                        key: ValueKey(_title),
                        textAlign: TextAlign.center,
                        style: context.text.titleLarge,
                      ),
                    ),
                  ),
                  const CartBadgeButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                12,
              ),
              child: AppTextField(
                hint: 'Rechercher un restaurant',
                prefixIcon: Icons.search_rounded,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            // Catégories (choix unique)
            SizedBox(
              height: 44,
              // Row dans un SingleChildScrollView : toutes les puces sont
              // construites, ce qui permet de faire défiler la sélection en vue.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                child: Row(
                  children: [
                    SelectableChip(
                      label: 'Tous',
                      selected: _categoryId == null,
                      onTap: () => setState(() => _categoryId = null),
                    ),
                    for (final c in CatalogMockData.categories) ...[
                      const SizedBox(width: 8),
                      SelectableChip(
                        key: _categoryId == c.id ? _selectedChipKey : null,
                        label: c.name,
                        emoji: c.emoji,
                        selected: _categoryId == c.id,
                        onTap: () => setState(() => _categoryId = c.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Filtres rapides (choix multiple)
            SizedBox(
              height: 44,
              // Row dans un SingleChildScrollView : toutes les puces sont
              // construites, ce qui permet de faire défiler la sélection en vue.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                child: Row(
                  children: [
                    SelectableChip(
                      label: 'Populaires',
                      icon: Icons.local_fire_department_rounded,
                      selected: _popularOnly,
                      onTap: () => setState(() => _popularOnly = !_popularOnly),
                    ),
                    for (final f in _QuickFilter.values) ...[
                      const SizedBox(width: 8),
                      SelectableChip(
                        label: f.label,
                        icon: f.icon,
                        selected: _filters.contains(f),
                        onTap: () => setState(
                          () => _filters.contains(f)
                              ? _filters.remove(f)
                              : _filters.add(f),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Nombre de résultats + tri
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                12,
                AppSizes.sm,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppDurations.fast,
                      child: Text(
                        _loading
                            ? 'Chargement…'
                            : '${results.length} établissement${results.length > 1 ? 's' : ''}',
                        key: ValueKey('${results.length}-$_loading'),
                        style: context.text.bodySmall,
                      ),
                    ),
                  ),
                  PopupMenuButton<_Sort>(
                    initialValue: _sort,
                    onSelected: (s) => setState(() => _sort = s),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    itemBuilder: (context) => [
                      for (final s in _Sort.values)
                        PopupMenuItem(value: s, child: Text(s.label)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_vert_rounded,
                            size: 18,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sort.label,
                            style: context.text.labelLarge?.copyWith(
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.medium,
                child: _loading
                    ? const RestaurantListShimmer(key: ValueKey('shimmer'))
                    : results.isEmpty
                    ? EmptyState(
                        key: const ValueKey('empty'),
                        icon: Icons.storefront_outlined,
                        title: 'Aucun établissement',
                        message: 'Aucun résultat avec ces filtres.',
                        actionLabel: 'Réinitialiser les filtres',
                        onAction: _resetFilters,
                      )
                    : ListView.separated(
                        key: listKey,
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          AppSizes.sm,
                          AppSizes.pagePadding,
                          AppSizes.xl,
                        ),
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.md),
                        itemBuilder: (context, i) =>
                            RestaurantTile(
                                  restaurant: results[i],
                                  // Unique par version de liste : l'ancienne liste
                                  // (en fondu sortant) ne partage pas ses tags Hero.
                                  heroOrigin: 'list${listKey.hashCode}',
                                )
                                .animate(delay: (60 * i.clamp(0, 6)).ms)
                                .fadeIn(duration: 400.ms)
                                .slideY(
                                  begin: 0.2,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
