import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import 'user_actions.dart';
import 'user_form.dart';
import 'users_controller.dart';

/// Module 1 (admin) : liste des utilisateurs avec recherche, filtres, tri,
/// création, modification, blocage, changement de rôle et suppression.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  /// Filtre rapide des pastilles (null = tous, sinon un rôle ou « bloqués »).
  Object? _quick;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersControllerProvider);
    final me = ref.watch(authServiceProvider).user;
    final all = users.value ?? const <User>[];
    final visible = switch (_quick) {
      final UserRole role => all.where((u) => u.role == role).toList(),
      UserStatus.blocked => all.where((u) => u.isBlocked).toList(),
      _ => users.value,
    };

    Widget pill(String label, Object? value, Color color, IconData icon) {
      final count = switch (value) {
        final UserRole role => all.where((u) => u.role == role).length,
        UserStatus.blocked => all.where((u) => u.isBlocked).length,
        _ => all.length,
      };
      return SummaryPill(
        label: label,
        value: count,
        color: color,
        icon: icon,
        selected: _quick == value,
        onTap: () => setState(() => _quick = value),
      );
    }

    return BoPage(
      title: 'Utilisateurs',
      subtitle: 'Clients, livreurs, restaurateurs et administrateurs.',
      onAdd: () => openUserForm(context),
      addLabel: 'Nouvel utilisateur',
      addIcon: Icons.person_add_alt_1_rounded,
      actions: [
        OutlinedButton.icon(
          onPressed: () => AppSnackbar.success(
            context,
            'Export CSV de ${all.length} utilisateurs prêt (démo).',
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Exporter'),
        ),
      ],
      children: [
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            pill('Tous', null, AppColors.primary, Icons.groups_rounded),
            pill('Clients', UserRole.client, AppColors.info, Icons.person_rounded),
            pill(
              'Livreurs',
              UserRole.courier,
              AppColors.warning,
              Icons.delivery_dining_rounded,
            ),
            pill(
              'Restaurants',
              UserRole.restaurant,
              AppColors.success,
              Icons.storefront_rounded,
            ),
            pill(
              'Admins',
              UserRole.admin,
              AppColors.secondary,
              Icons.admin_panel_settings_rounded,
            ),
            pill('Bloqués', UserStatus.blocked, AppColors.error, Icons.block_rounded),
          ],
        ),
        boGap,
        AppDataTable<User>(
          items: visible,
          isLoading: users.isLoading,
          error: users.error,
          onRetry: () => ref.invalidate(usersControllerProvider),
          searchHint: 'Nom, e-mail, téléphone…',
          searchText: (u) => '${u.fullName} ${u.email} ${u.phone}',
          initialSortColumn: 4,
          initialSortAscending: false,
          filters: [
            AppTableFilter(
              label: 'Statut',
              icon: Icons.toggle_on_outlined,
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
              cell: (context, u) => UserCell(user: u, isMe: u.id == me?.id),
            ),
            AppTableColumn(
              label: 'Téléphone',
              flex: 2,
              cell: (context, u) =>
                  Text(u.phone, style: context.text.bodyMedium),
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
              cell: (context, u) => Text(
                Formatters.date(u.createdAt),
                style: context.text.bodySmall,
              ),
            ),
            AppTableColumn(
              label: 'Dernière connexion',
              sortValue: (u) => u.lastLoginAt ?? DateTime(2000),
              cell: (context, u) => Text(
                u.lastLoginAt == null
                    ? 'Jamais'
                    : Formatters.relative(u.lastLoginAt!),
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
          onView: (u) => context.go(BackRoutes.user(u.id)),
          onEdit: (u) => openUserForm(context, user: u),
          onDelete: (u) async {
            if (u.id == me?.id) {
              throw const ApiException(
                'Vous ne pouvez pas supprimer votre propre compte.',
              );
            }
            await ref.read(usersControllerProvider.notifier).remove(u.id);
          },
          deleteMessage: (u) =>
              '${u.fullName} et son accès seront supprimés définitivement.',
          actions: userTableActions(context, ref, meId: me?.id),
        ),
      ],
    );
  }
}

/// Avatar, nom et e-mail d'un utilisateur (cellule de tableau).
class UserCell extends StatelessWidget {
  const UserCell({super.key, required this.user, this.isMe = false});

  final User user;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(name: user.fullName, imageUrl: user.avatarUrl, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: user.fullName,
                  children: [
                    if (isMe)
                      TextSpan(
                        text: '  (vous)',
                        style: TextStyle(
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                user.email,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
