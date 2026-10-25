import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_search_field.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../providers/catalog_providers.dart';

/// Recherche (onglet) : restaurants et plats, recherches récentes et
/// catégories en raccourci.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    _controller.text = query;
    setState(() => _query = query.trim());
    ref.read(recentSearchesProvider.notifier).add(query);
  }

  void _openRestaurant(String id) =>
      context.push(FrontRoutes.restaurant(id, tab: FrontRoutes.search));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.md,
              ),
              child: PageTitle('Recherche'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding,
              ),
              child: AppSearchField(
                controller: _controller,
                hint: 'Restaurants, plats, cuisines…',
                onChanged: (q) => setState(() => _query = q),
                onSubmitted: _search,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.fast,
                child: _query.isEmpty
                    ? _Suggestions(key: const ValueKey('s'), onSearch: _search)
                    : _Results(
                        key: ValueKey(_query),
                        query: _query,
                        onRestaurant: _openRestaurant,
                        onDone: () => ref
                            .read(recentSearchesProvider.notifier)
                            .add(_query),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recherches récentes',
                  style: context.text.titleMedium,
                ),
              ),
              TextButton(
                onPressed: ref.read(recentSearchesProvider.notifier).clear,
                child: const Text('Effacer'),
              ),
            ],
          ),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final q in recent)
                InputChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(q),
                  onPressed: () => onSearch(q),
                  onDeleted: () =>
                      ref.read(recentSearchesProvider.notifier).remove(q),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
        ],
        Text('Envie de…', style: context.text.titleMedium),
        const SizedBox(height: AppSizes.md),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSizes.md,
          crossAxisSpacing: AppSizes.md,
          childAspectRatio: 0.95,
          children: [
            for (final (i, c) in categories.indexed)
              Container(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Color(c.colorValue).withValues(alpha: 0.15)
                      : Color(c.colorValue),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  onTap: () => onSearch(c.name),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge,
                      ),
                    ],
                  ),
                ),
              ).animate(delay: (30 * i).ms).fadeIn().scaleXY(begin: 0.9),
          ],
        ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    super.key,
    required this.query,
    required this.onRestaurant,
    required this.onDone,
  });

  final String query;
  final ValueChanged<String> onRestaurant;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider(query));
    return results.when(
      loading: () => ShimmerScope(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSizes.md),
                child: SkeletonBox(height: 90, radius: AppSizes.radiusMd),
              ),
          ],
        ),
      ),
      error: (e, _) => Center(child: Text('$e')),
      data: (r) {
        if (r.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Aucun résultat',
            message: 'Rien ne correspond à « $query ». Essayez un autre mot.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.sm,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children: [
            if (r.restaurants.isNotEmpty) ...[
              Text(
                'Restaurants (${r.restaurants.length})',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: AppSizes.sm),
              for (final (i, restaurant) in r.restaurants.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.sm + 4),
                  child: RestaurantTile(
                    restaurant: restaurant,
                    onTap: () {
                      onDone();
                      onRestaurant(restaurant.id);
                    },
                  ).animate(delay: (40 * i).ms).fadeIn().slideX(begin: 0.05),
                ),
              const SizedBox(height: AppSizes.md),
            ],
            if (r.products.isNotEmpty) ...[
              Text('Plats (${r.products.length})', style: context.text.titleMedium),
              const SizedBox(height: AppSizes.sm),
              for (final (i, (product, restaurant)) in r.products.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    onDone();
                    onRestaurant(restaurant.id);
                  },
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: AppNetworkImage(
                      product.imageUrl,
                      width: 56,
                      height: 56,
                    ),
                  ),
                  title: Text(product.name, style: context.text.titleSmall),
                  subtitle: Text(
                    restaurant.name,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  trailing: Text(
                    Formatters.price(product.price),
                    style: context.text.titleSmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ).animate(delay: (30 * (i % 10)).ms).fadeIn(),
            ],
          ],
        );
      },
    );
  }
}
