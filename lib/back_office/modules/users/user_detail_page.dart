import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import '../catalog/catalog_controllers.dart';
import '../delivery/delivery_controllers.dart';
import '../orders/orders_controller.dart';
import 'user_actions.dart';
import 'user_form.dart';
import 'users_controller.dart';

/// Adresses d'un utilisateur (fiche détail).
final userAddressesProvider = FutureProvider.autoDispose
    .family<List<Address>, String>(
      (ref, userId) => ref.watch(addressRepositoryProvider).forUser(userId),
    );

/// Fiche d'un utilisateur : identité, actions et données liées au rôle
/// (adresses et commandes d'un client, restaurant géré, profil livreur).
class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({super.key, required this.userId});

  final String userId;

  static const _parent = 'Utilisateurs';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersControllerProvider);
    final parent = BreadcrumbItem(
      _parent,
      onTap: () => context.go(BackRoutes.users),
    );
    final user = users.value?.where((u) => u.id == userId).firstOrNull;

    if (user == null) {
      return BoPage(
        title: users.isLoading ? 'Chargement…' : 'Utilisateur introuvable',
        parent: parent,
        children: [
          if (users.isLoading)
            const ShimmerScope(
              child: SkeletonBox(height: 220, radius: AppSizes.radiusLg),
            )
          else
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.person_off_rounded,
                title: 'Utilisateur introuvable',
                message: 'Ce compte a peut-être été supprimé.',
                actionLabel: 'Retour à la liste',
                onAction: () => context.go(BackRoutes.users),
              ),
            ),
        ],
      );
    }

    final isMe = ref.watch(authServiceProvider).user?.id == user.id;
    return BoPage(
      title: user.fullName,
      parent: parent,
      actions: [
        OutlinedButton.icon(
          onPressed: () => openUserForm(context, user: user),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Modifier'),
        ),
        if (!isMe)
          PopupMenuButton<String>(
            tooltip: "Plus d'actions",
            onSelected: (action) => switch (action) {
              'role' => changeUserRole(context, ref, user),
              'block' => toggleUserBlocked(context, ref, user),
              _ => _delete(context, ref, user),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'role',
                child: ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Changer le rôle'),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: ListTile(
                  leading: Icon(
                    user.isBlocked
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                  ),
                  title: Text(user.isBlocked ? 'Débloquer' : 'Bloquer'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Supprimer',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: context.palette.border),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_horiz_rounded),
                  SizedBox(width: 6),
                  Text('Actions'),
                ],
              ),
            ),
          ),
      ],
      children: [
        _ProfileBanner(user: user, isMe: isMe),
        boGap,
        SplitRow(
          leftFlex: 2,
          rightFlex: 3,
          left: _InfoCard(user: user),
          right: switch (user.role) {
            UserRole.client => _ClientActivity(user: user),
            UserRole.courier => _CourierLink(user: user),
            UserRole.restaurant => _RestaurantLink(user: user),
            UserRole.admin => const SectionCard(
              title: 'Administrateur',
              icon: Icons.admin_panel_settings_rounded,
              child: Text(
                'Accès complet à l’Espace Pro : utilisateurs, catalogue, '
                'commandes, livraisons et communication.',
              ),
            ),
          },
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, User user) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Supprimer ${user.fullName} ?',
      message: 'Le compte et son accès seront supprimés définitivement.',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(usersControllerProvider.notifier).remove(user.id);
      if (!context.mounted) return;
      AppSnackbar.success(context, 'Utilisateur supprimé');
      context.go(BackRoutes.users);
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.user, required this.isMe});

  final User user;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 84,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppSizes.md,
              runSpacing: AppSizes.sm,
              children: [
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Avatar(
                    name: user.fullName,
                    imageUrl: user.avatarUrl,
                    size: 88,
                    border: true,
                  ).animate().scaleXY(begin: 0.7, curve: Curves.easeOutBack),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${user.fullName} (vous)' : user.fullName,
                        style: context.text.titleLarge,
                      ),
                      Text(
                        user.email,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Wrap(
                        spacing: AppSizes.sm,
                        runSpacing: AppSizes.sm,
                        children: [
                          userRoleChip(user.role),
                          userStatusChip(user.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Informations',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          infoText(Icons.mail_outline_rounded, 'E-mail', user.email),
          infoText(Icons.phone_outlined, 'Téléphone', user.phone),
          infoText(
            Icons.event_rounded,
            'Inscription',
            Formatters.date(user.createdAt),
          ),
          infoText(
            Icons.login_rounded,
            'Dernière connexion',
            user.lastLoginAt == null
                ? 'Jamais'
                : Formatters.dateTime(user.lastLoginAt!),
          ),
          if (user.role == UserRole.client)
            infoText(
              Icons.loyalty_outlined,
              'Points de fidélité',
              '${Formatters.count(user.loyaltyPoints)} pts',
            ),
          infoText(Icons.tag_rounded, 'Identifiant', user.id),
        ],
      ),
    );
  }
}

/// Client : statistiques, adresses et historique des commandes.
class _ClientActivity extends ConsumerWidget {
  const _ClientActivity({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = (ref.watch(ordersControllerProvider).value ?? const [])
        .where((o) => o.userId == user.id)
        .toList();
    final spent = orders
        .where(
          (o) =>
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.refunded,
        )
        .fold<double>(0, (s, o) => s + o.total);
    final addresses = ref.watch(userAddressesProvider(user.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: 160,
          maxColumns: 3,
          children: [
            _MiniStat(
              label: 'Commandes',
              value: Formatters.count(orders.length),
              icon: Icons.receipt_long_rounded,
              color: AppColors.primary,
            ),
            _MiniStat(
              label: 'Total dépensé',
              value: Formatters.priceShort(spent),
              icon: Icons.euro_rounded,
              color: AppColors.success,
            ),
            _MiniStat(
              label: 'Panier moyen',
              value: orders.isEmpty
                  ? '—'
                  : Formatters.price(spent / orders.length),
              icon: Icons.shopping_bag_rounded,
              color: AppColors.info,
            ),
          ],
        ),
        boGap,
        SectionCard(
          title: 'Adresses',
          icon: Icons.place_outlined,
          child: addresses.when(
            loading: () => const ShimmerScope(child: SkeletonBox(height: 60)),
            error: (e, _) => Text('$e'),
            data: (list) => list.isEmpty
                ? Text(
                    'Aucune adresse enregistrée.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  )
                : Column(
                    children: [
                      for (final a in list)
                        InfoRow(
                          icon: switch (a.type) {
                            AddressType.home => Icons.home_outlined,
                            AddressType.work => Icons.work_outline_rounded,
                            AddressType.other => Icons.place_outlined,
                          },
                          label: a.isDefault
                              ? '${a.label} • par défaut'
                              : a.label,
                          value: Text(a.fullAddress),
                        ),
                    ],
                  ),
          ),
        ),
        boGap,
        SectionCard(
          title: 'Commandes',
          icon: Icons.history_rounded,
          subtitle: '${orders.length} commande${orders.length > 1 ? 's' : ''}',
          child: orders.isEmpty
              ? const EmptyState(
                  compact: true,
                  title: 'Aucune commande',
                  message: "Ce client n'a encore rien commandé.",
                )
              : DividedColumn(
                  children: [
                    for (final o in orders.take(8)) OrderListTile(order: o),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: context.text.titleLarge),
                ),
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Restaurateur : restaurant géré.
class _RestaurantLink extends ConsumerWidget {
  const _RestaurantLink({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = (ref.watch(restaurantsControllerProvider).value ?? [])
        .where((r) => r.id == user.restaurantId)
        .firstOrNull;
    return SectionCard(
      title: 'Restaurant géré',
      icon: Icons.storefront_rounded,
      child: restaurant == null
          ? Text(
              'Aucun restaurant associé à ce compte.',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            )
          : ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(
                name: restaurant.name,
                imageUrl: restaurant.imageUrl,
                size: 48,
              ),
              title: Text(restaurant.name),
              subtitle: Text('${restaurant.cuisine} • ${restaurant.address}'),
              trailing: restaurantStatusChip(restaurant.status),
              onTap: () => context.go(BackRoutes.restaurant(restaurant.id)),
            ),
    );
  }
}

/// Livreur : profil livreur (véhicule, statut, justificatifs).
class _CourierLink extends ConsumerWidget {
  const _CourierLink({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courier = (ref.watch(couriersControllerProvider).value ?? [])
        .where((c) => c.userId == user.id)
        .firstOrNull;
    return SectionCard(
      title: 'Profil livreur',
      icon: Icons.delivery_dining_rounded,
      child: courier == null
          ? Text(
              'Aucun profil livreur associé.',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoText(
                  Icons.two_wheeler_rounded,
                  'Véhicule',
                  courier.vehicle.label,
                ),
                infoText(Icons.map_outlined, 'Zone', courier.zone),
                InfoRow(
                  icon: Icons.circle_outlined,
                  label: 'Statut',
                  value: Align(
                    alignment: Alignment.centerLeft,
                    child: courierStatusChip(courier.status),
                  ),
                ),
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Justificatifs',
                  value: Align(
                    alignment: Alignment.centerLeft,
                    child: documentStatusChip(courier.documentStatus),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        context.go(BackRoutes.courier(courier.id)),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Voir la fiche livreur'),
                  ),
                ),
              ],
            ),
    );
  }
}
