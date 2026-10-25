import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app/bootstrap.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_sizes.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_extensions.dart';
import '../core/theme/theme_mode_provider.dart';
import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_charts.dart';
import '../core/widgets/app_data_table.dart';
import '../core/widgets/app_form.dart';
import '../core/widgets/app_form_fields.dart';
import '../core/widgets/app_network_image.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/async_value_view.dart';
import '../core/widgets/chart_card.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/page_header.dart';
import '../core/widgets/shimmer_box.dart';
import '../core/widgets/stat_card.dart';
import '../shared/models/models.dart';
import '../shared/repositories/repository_providers.dart';
import '../shared/widgets/status_chips.dart';

// =============================================================================
// Catalogue des composants (étape 1) : les widgets génériques de core/
// branchés sur les dépôts mock de shared/. Les deux points d'entrée l'affichent
// en attendant le front office (étape 2) et le back office (étape 3).
// =============================================================================

class ComponentGalleryApp extends ConsumerWidget {
  const ComponentGalleryApp({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: AppLocalization.locale,
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: AppLocalization.delegates,
      home: ComponentGalleryPage(title: title),
    );
  }
}

class ComponentGalleryPage extends ConsumerWidget {
  const ComponentGalleryPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Thème clair / sombre',
            onPressed: ref.read(themeModeProvider.notifier).toggle,
            icon: Icon(
              context.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: 'Composants SuperFaster',
                    subtitle:
                        'Étape 1 : thème, composants génériques et données mock.',
                    breadcrumbs: const [
                      BreadcrumbItem('Accueil'),
                      BreadcrumbItem('Composants'),
                    ],
                    addLabel: 'Nouvel utilisateur',
                    onAdd: () => openUserForm(context, ref),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  const _StatsAndCharts(),
                  const SizedBox(height: AppSizes.lg),
                  const _ChipsSection(),
                  const SizedBox(height: AppSizes.lg),
                  const _UsersTable(),
                  const SizedBox(height: AppSizes.lg),
                  const AppCard(
                    child: EmptyState(
                      compact: true,
                      title: 'État vide',
                      message:
                          'Affiché par AppDataTable quand aucun élément ne '
                          'correspond à la recherche.',
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Statistiques et graphiques (calculés depuis les dépôts mock)
// -----------------------------------------------------------------------------
class GalleryStats {
  const GalleryStats({
    required this.ordersToday,
    required this.revenueToday,
    required this.users,
    required this.activeCouriers,
    required this.sales,
    required this.days,
    required this.statusSlices,
    required this.topProducts,
  });

  final int ordersToday;
  final double revenueToday;
  final int users;
  final int activeCouriers;
  final List<double> sales;
  final List<String> days;
  final List<ChartSlice> statusSlices;
  final List<ChartBar> topProducts;
}

final galleryStatsProvider = FutureProvider<GalleryStats>((ref) async {
  final (orders, users, couriers) = await (
    ref.watch(orderRepositoryProvider).getAll(),
    ref.watch(userRepositoryProvider).getAll(),
    ref.watch(courierRepositoryProvider).getAll(),
  ).wait;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final paid = orders.where(
    (o) =>
        o.status != OrderStatus.cancelled && o.status != OrderStatus.refunded,
  );

  // Ventes des 7 derniers jours (le plus ancien à gauche).
  final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  final sales = [
    for (final day in days)
      paid
          .where((o) => sameDay(o.createdAt, day))
          .fold<double>(0, (sum, o) => sum + o.total),
  ];

  int countWhere(bool Function(OrderStatus s) test) =>
      orders.where((o) => test(o.status)).length;

  // Top 5 des produits les plus commandés.
  final quantities = <String, int>{};
  for (final order in orders) {
    for (final item in order.items) {
      quantities.update(
        item.product.name,
        (q) => q + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
  }
  final top = quantities.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return GalleryStats(
    ordersToday: orders.where((o) => sameDay(o.createdAt, today)).length,
    revenueToday: sales.last,
    users: users.length,
    activeCouriers: couriers.where((c) => c.status.isOnline).length,
    sales: sales,
    days: [for (final d in days) Formatters.weekday(d)],
    statusSlices: [
      ChartSlice(
        label: 'Nouvelles',
        value: countWhere((s) => s == OrderStatus.pending).toDouble(),
        color: AppColors.info,
      ),
      ChartSlice(
        label: 'En cours',
        value: countWhere(
          (s) => s.isActive && s != OrderStatus.pending,
        ).toDouble(),
        color: AppColors.primary,
      ),
      ChartSlice(
        label: 'Livrées',
        value: countWhere((s) => s == OrderStatus.delivered).toDouble(),
        color: AppColors.success,
      ),
      ChartSlice(
        label: 'Annulées / remboursées',
        value: countWhere(
          (s) => s == OrderStatus.cancelled || s == OrderStatus.refunded,
        ).toDouble(),
        color: AppColors.error,
      ),
    ],
    topProducts: [
      for (final e in top.take(5))
        ChartBar(label: e.key, value: e.value.toDouble()),
    ],
  );
});

class _StatsAndCharts extends ConsumerWidget {
  const _StatsAndCharts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(galleryStatsProvider),
      onRetry: () => ref.invalidate(galleryStatsProvider),
      loading: const ShimmerScope(child: SkeletonBox(height: 160)),
      data: (stats) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width > 1000 ? 4 : (width > 330 ? 2 : 1);
          final cardWidth = (width - AppSizes.md * (columns - 1)) / columns;
          final cards = [
            StatCard(
              label: 'Commandes du jour',
              value: stats.ordersToday,
              icon: Icons.receipt_long_rounded,
              trend: 12.5,
            ),
            StatCard(
              label: 'Revenus du jour',
              value: stats.revenueToday,
              format: Formatters.priceShort,
              icon: Icons.euro_rounded,
              color: AppColors.success,
              trend: 8.1,
            ),
            StatCard(
              label: 'Utilisateurs',
              value: stats.users,
              icon: Icons.groups_rounded,
              color: AppColors.info,
              trend: 3.4,
            ),
            StatCard(
              label: 'Livreurs actifs',
              value: stats.activeCouriers,
              icon: Icons.delivery_dining_rounded,
              color: AppColors.warning,
              trend: -4.2,
            ),
          ];
          final line = ChartCard(
            title: 'Ventes sur 7 jours',
            subtitle: 'Hors commandes annulées',
            child: AppLineChart(values: stats.sales, labels: stats.days),
          );
          final pie = ChartCard(
            title: 'Commandes par statut',
            child: AppPieChart(
              slices: stats.statusSlices,
              centerLabel: Formatters.count(
                stats.statusSlices.fold<double>(0, (s, e) => s + e.value),
              ),
            ),
          );
          final bars = ChartCard(
            title: 'Top produits',
            subtitle: 'Quantités commandées',
            height: 220,
            child: AppBarChart(bars: stats.topProducts),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSizes.md,
                runSpacing: AppSizes.md,
                children: [
                  for (final (i, card) in cards.indexed)
                    SizedBox(width: cardWidth, child: card)
                        .animate(delay: (80 * i).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.15, end: 0),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              if (width > 900)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: line),
                    const SizedBox(width: AppSizes.md),
                    Expanded(flex: 2, child: pie),
                  ],
                )
              else ...[
                line,
                const SizedBox(height: AppSizes.md),
                pie,
              ],
              const SizedBox(height: AppSizes.md),
              bars,
            ],
          );
        },
      ),
    );
  }
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statuts', style: context.text.titleMedium),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final s in OrderStatus.values) orderStatusChip(s),
              for (final r in UserRole.values) userRoleChip(r),
              for (final s in DeliveryStatus.values) deliveryStatusChip(s),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CRUD des utilisateurs : AppDataTable + AppForm sur le dépôt mock
// -----------------------------------------------------------------------------
final galleryUsersProvider =
    AsyncNotifierProvider<GalleryUsersController, List<User>>(
      GalleryUsersController.new,
    );

class GalleryUsersController extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() => ref.watch(userRepositoryProvider).getAll();

  Future<void> _reload() async {
    ref.invalidateSelf();
    ref.invalidate(galleryStatsProvider);
    await future;
  }

  Future<void> save(User user) async {
    final repository = ref.read(userRepositoryProvider);
    user.id.isEmpty
        ? await repository.create(user)
        : await repository.update(user);
    await _reload();
  }

  Future<void> remove(User user) async {
    await ref.read(userRepositoryProvider).delete(user.id);
    await _reload();
  }

  Future<void> toggleBlocked(User user) async {
    await ref
        .read(userRepositoryProvider)
        .setStatus(
          user.id,
          user.isBlocked ? UserStatus.active : UserStatus.blocked,
        );
    await _reload();
  }
}

class _UsersTable extends ConsumerWidget {
  const _UsersTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(galleryUsersProvider);
    final controller = ref.read(galleryUsersProvider.notifier);

    return AppDataTable<User>(
      items: users.value,
      isLoading: users.isLoading,
      error: users.error,
      onRetry: () => ref.invalidate(galleryUsersProvider),
      searchHint: 'Nom, e-mail, téléphone…',
      searchText: (u) => '${u.fullName} ${u.email} ${u.phone}',
      initialSortColumn: 3,
      initialSortAscending: false,
      filters: [
        AppTableFilter(
          label: 'Rôle',
          icon: Icons.badge_outlined,
          options: {for (final r in UserRole.values) r.name: r.label},
          test: (u, v) => u.role.name == v,
        ),
        AppTableFilter(
          label: 'Statut',
          options: {for (final s in UserStatus.values) s.name: s.label},
          test: (u, v) => u.status.name == v,
        ),
      ],
      columns: [
        AppTableColumn(
          label: 'Utilisateur',
          primary: true,
          flex: 4,
          sortValue: (u) => u.fullName,
          cell: (context, u) => _UserCell(user: u),
        ),
        AppTableColumn(
          label: 'Rôle',
          sortValue: (u) => u.role.index,
          cell: (_, u) => userRoleChip(u.role),
        ),
        AppTableColumn(
          label: 'Statut',
          sortValue: (u) => u.status.index,
          cell: (_, u) => userStatusChip(u.status),
        ),
        AppTableColumn(
          label: 'Inscription',
          sortValue: (u) => u.createdAt,
          cell: (context, u) =>
              Text(Formatters.date(u.createdAt), style: context.text.bodySmall),
        ),
      ],
      onEdit: (u) => openUserForm(context, ref, user: u),
      onDelete: controller.remove,
      deleteMessage: (u) => '${u.fullName} sera supprimé définitivement.',
      actions: [
        AppTableAction(
          label: 'Bloquer',
          icon: Icons.block_rounded,
          isDestructive: true,
          isVisible: (u) => !u.isBlocked,
          onSelected: controller.toggleBlocked,
        ),
        AppTableAction(
          label: 'Débloquer',
          icon: Icons.lock_open_rounded,
          isVisible: (u) => u.isBlocked,
          onSelected: controller.toggleBlocked,
        ),
      ],
    );
  }
}

class _UserCell extends StatelessWidget {
  const _UserCell({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(
          child: AppNetworkImage(
            user.avatarUrl ?? '',
            width: 38,
            height: 38,
            fallbackIcon: Icons.person_rounded,
          ),
        ),
        const SizedBox(width: AppSizes.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: context.text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                user.email,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Création ([user] null) ou modification d'un utilisateur.
Future<void> openUserForm(BuildContext context, WidgetRef ref, {User? user}) =>
    showAppForm(context, UserForm(user: user));

class UserForm extends ConsumerStatefulWidget {
  const UserForm({super.key, this.user});

  final User? user;

  @override
  ConsumerState<UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<UserForm> {
  late final _first = TextEditingController(text: widget.user?.firstName);
  late final _last = TextEditingController(text: widget.user?.lastName);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  late UserRole _role = widget.user?.role ?? UserRole.client;
  late UserStatus _status = widget.user?.status ?? UserStatus.active;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() {
    final base =
        widget.user ??
        User(
          id: '',
          firstName: '',
          lastName: '',
          email: '',
          phone: '',
          role: _role,
          createdAt: DateTime.now(),
        );
    return ref
        .read(galleryUsersProvider.notifier)
        .save(
          base.copyWith(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            status: _status,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.user == null;
    return AppForm(
      title: isNew ? 'Nouvel utilisateur' : 'Modifier l\'utilisateur',
      subtitle: isNew ? null : widget.user!.email,
      icon: isNew
          ? Icons.person_add_alt_1_rounded
          : Icons.manage_accounts_rounded,
      successMessage: isNew ? 'Utilisateur créé' : 'Modifications enregistrées',
      onSubmit: _save,
      children: [
        const AppFormSection(title: 'Identité'),
        AppFormRow(
          children: [
            AppTextField(
              controller: _first,
              label: 'Prénom',
              validator: Validators.name,
            ),
            AppTextField(
              controller: _last,
              label: 'Nom',
              validator: Validators.name,
            ),
          ],
        ),
        AppTextField(
          controller: _email,
          label: 'Adresse e-mail',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
        ),
        AppTextField(
          controller: _phone,
          label: 'Téléphone',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: Validators.phone,
        ),
        const AppFormSection(title: 'Accès'),
        AppFormRow(
          children: [
            AppDropdownField<UserRole>(
              label: 'Rôle',
              value: _role,
              items: UserRole.values,
              itemLabel: (r) => r.label,
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
            AppDropdownField<UserStatus>(
              label: 'Statut',
              value: _status,
              items: UserStatus.values,
              itemLabel: (s) => s.label,
              onChanged: (s) => setState(() => _status = s ?? _status),
            ),
          ],
        ),
      ],
    );
  }
}
