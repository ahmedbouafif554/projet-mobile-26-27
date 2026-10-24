import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/user.dart';
import '../modules/catalog/catalog_controllers.dart';
import '../modules/delivery/delivery_controllers.dart';
import '../modules/orders/orders_controller.dart';
import '../modules/users/users_controller.dart';
import '../router/back_routes.dart';
import 'back_nav.dart';

/// Résultat de la recherche globale.
class SearchHit {
  const SearchHit({
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String group;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

/// Recherche dans les données visibles par le rôle : commandes, produits,
/// et pour l'admin restaurants, utilisateurs et livreurs.
Future<List<SearchHit>> searchEverything(WidgetRef ref, String query) async {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  bool match(String text) => text.toLowerCase().contains(q);
  final auth = ref.read(authServiceProvider);
  const perGroup = 4;

  final hits = <SearchHit>[];
  final orders = await ref.read(ordersControllerProvider.future);
  hits.addAll(
    orders
        .where(
          (o) => match('${o.reference} ${o.customerName} ${o.restaurantName}'),
        )
        .take(perGroup)
        .map(
          (o) => SearchHit(
            group: 'Commandes',
            title: '#${o.reference} • ${o.customerName}',
            subtitle:
                '${o.restaurantName} • ${o.status.label} • ${Formatters.price(o.total)}',
            icon: Icons.receipt_long_rounded,
            route: BackRoutes.order(o.id),
          ),
        ),
  );

  final products = await ref.read(productsControllerProvider.future);
  hits.addAll(
    products
        .where((p) => match('${p.name} ${p.section}'))
        .take(perGroup)
        .map(
          (p) => SearchHit(
            group: 'Produits',
            title: p.name,
            subtitle: '${p.section} • ${Formatters.price(p.price)}',
            icon: Icons.fastfood_rounded,
            route: BackRoutes.products,
          ),
        ),
  );

  if (auth.can(Permission.manageRestaurants)) {
    final restaurants = await ref.read(restaurantsControllerProvider.future);
    hits.addAll(
      restaurants
          .where((r) => match('${r.name} ${r.cuisine} ${r.address}'))
          .take(perGroup)
          .map(
            (r) => SearchHit(
              group: 'Restaurants',
              title: r.name,
              subtitle: '${r.cuisine} • ${r.status.label}',
              icon: Icons.storefront_rounded,
              route: BackRoutes.restaurant(r.id),
            ),
          ),
    );
  }
  if (auth.can(Permission.manageUsers)) {
    final users = await ref.read(usersControllerProvider.future);
    hits.addAll(
      users
          .where((u) => match('${u.fullName} ${u.email} ${u.phone}'))
          .take(perGroup)
          .map(
            (u) => SearchHit(
              group: 'Utilisateurs',
              title: u.fullName,
              subtitle: '${u.role.label} • ${u.email}',
              icon: Icons.person_rounded,
              route: BackRoutes.user(u.id),
            ),
          ),
    );
  }
  if (auth.can(Permission.manageCouriers)) {
    final couriers = await ref.read(couriersControllerProvider.future);
    hits.addAll(
      couriers
          .where((c) => match('${c.fullName} ${c.zone} ${c.phone}'))
          .take(perGroup)
          .map(
            (c) => SearchHit(
              group: 'Livreurs',
              title: c.fullName,
              subtitle: '${c.vehicle.label} • ${c.zone} • ${c.status.label}',
              icon: Icons.delivery_dining_rounded,
              route: BackRoutes.courier(c.id),
            ),
          ),
    );
  }
  return hits;
}

/// Barre de recherche globale de la topbar (ou simple icône sur mobile).
class GlobalSearch extends ConsumerStatefulWidget {
  const GlobalSearch({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  ConsumerState<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends ConsumerState<GlobalSearch> {
  final _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(String route) {
    _controller.closeView('');
    context.go(route);
  }

  Widget _tile(IconData icon, String title, String subtitle, String route) =>
      ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _open(route),
      );

  Widget _groupTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.palette.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );

  Future<Iterable<Widget>> _suggestions(
    BuildContext context,
    SearchController controller,
  ) async {
    final query = controller.text;
    final role = ref.read(authServiceProvider).role;
    final muted = context.palette.textSecondary;
    if (query.trim().isEmpty) {
      // Raccourcis : les pages du menu.
      return [
        _groupTitle('Aller à'),
        if (role != null)
          for (final group in navFor(role))
            for (final item in group.items)
              _tile(
                item.icon,
                item.labelFor(role),
                group.title ?? 'Accueil',
                item.path,
              ),
      ];
    }
    final hits = await searchEverything(ref, query);
    if (!mounted) return const [];
    if (hits.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: muted),
              const SizedBox(height: 8),
              Text('Aucun résultat pour « ${query.trim()} »'),
            ],
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    String? group;
    for (final hit in hits) {
      if (hit.group != group) {
        group = hit.group;
        widgets.add(_groupTitle(hit.group));
      }
      widgets.add(_tile(hit.icon, hit.title, hit.subtitle, hit.route));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authServiceProvider.select((a) => a.role));
    final hint = role == UserRole.admin
        ? 'Rechercher commandes, restaurants, utilisateurs…'
        : 'Rechercher commandes, produits…';
    return SearchAnchor(
      searchController: _controller,
      viewHintText: hint,
      viewBackgroundColor: context.colors.surface,
      viewElevation: 8,
      dividerColor: context.palette.border,
      viewConstraints: const BoxConstraints(maxHeight: 460, minWidth: 360),
      isFullScreen: widget.iconOnly ? true : null,
      builder: (context, controller) {
        if (widget.iconOnly) {
          return IconButton(
            tooltip: 'Rechercher',
            onPressed: controller.openView,
            icon: const Icon(Icons.search_rounded),
          );
        }
        return SearchBar(
          controller: controller,
          hintText: hint,
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(
            context.palette.surfaceMuted,
          ),
          constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
          hintStyle: WidgetStatePropertyAll(
            context.text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          leading: Icon(
            Icons.search_rounded,
            color: context.palette.textSecondary,
          ),
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
        );
      },
      suggestionsBuilder: _suggestions,
    );
  }
}
