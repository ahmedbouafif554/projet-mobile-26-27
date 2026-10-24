import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/page_title.dart';
import '../../data/catalog_mock_data.dart';
import '../widgets/catalog_shimmers.dart';
import '../widgets/category_item.dart';
import '../widgets/product_tile.dart';
import '../widgets/restaurant_tile.dart';

/// Onglet Recherche : suggestions, puis résultats (restaurants et plats)
/// avec un court shimmer simulant l'appel réseau.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _query = value.trim();
      _searching = _query.isNotEmpty;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _searching = false);
    });
  }

  void _pick(String term) {
    _controller.text = term;
    _onChanged(term);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_query.isEmpty) {
      body = _Suggestions(key: const ValueKey('suggestions'), onPick: _pick);
    } else if (_searching) {
      body = const RestaurantListShimmer(key: ValueKey('loading'));
    } else {
      body = _Results(key: ValueKey('results-$_query'), query: _query);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageTitle('Recherche'),
                  const SizedBox(height: AppSizes.md),
                  AppTextField(
                    controller: _controller,
                    hint: 'Burger, sushi, Pizza Napoli…',
                    prefixIcon: Icons.search_rounded,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    suffix: AnimatedSwitcher(
                      duration: AppDurations.fast,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _query.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              key: const ValueKey('clear'),
                              onPressed: _clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.medium,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Suggestions affichées quand le champ est vide.
class _Suggestions extends StatelessWidget {
  const _Suggestions({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Text('Recherches récentes', style: context.text.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in CatalogMockData.recentSearches)
              Pressable(
                onTap: () => onPick(term),
                scale: 0.94,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: context.palette.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(term, style: context.text.labelLarge),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        Text('Explorer par catégorie', style: context.text.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // 4 colonnes sur téléphone, plus sur grand écran.
            final columns = (constraints.maxWidth / 86).floor().clamp(3, 6);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                for (final (i, category) in CatalogMockData.categories.indexed)
                  CategoryItem(
                        category: category,
                        onTap: () => context.push(
                          AppRoutes.restaurantsWith(category: category.id),
                        ),
                      )
                      .animate(delay: (40 * i).ms)
                      .fadeIn()
                      .scaleXY(begin: 0.8, end: 1),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Résultats de recherche.
class _Results extends StatelessWidget {
  const _Results({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final restaurants = CatalogMockData.searchRestaurants(query);
    final products = CatalogMockData.searchProducts(query);

    if (restaurants.isEmpty && products.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Aucun résultat pour « $query ».\nEssayez un autre mot-clé.',
      );
    }

    // Origine Hero propre à cette recherche (évite les doublons de tags
    // pendant le fondu entre deux listes de résultats).
    final heroOrigin = 'search${query.hashCode}';
    var index = 0;
    Widget cascade(Widget child) => child
        .animate(delay: (50 * (index++).clamp(0, 8)).ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.15, end: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      children: [
        if (restaurants.isNotEmpty) ...[
          Text(
            'Restaurants (${restaurants.length})',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final r in restaurants)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.md),
              child: cascade(
                RestaurantTile(restaurant: r, heroOrigin: heroOrigin),
              ),
            ),
        ],
        if (products.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sm),
          Text('Plats (${products.length})', style: context.text.titleMedium),
          const SizedBox(height: 12),
          for (final p in products)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: cascade(ProductTile(product: p, heroOrigin: heroOrigin)),
            ),
        ],
      ],
    );
  }
}
