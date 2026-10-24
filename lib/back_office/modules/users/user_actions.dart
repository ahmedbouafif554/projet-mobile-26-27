import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../shared/models/user.dart';
import 'user_form.dart';
import 'users_controller.dart';

// =============================================================================
// Actions sur un utilisateur, partagées par le tableau et la fiche détail.
// =============================================================================

/// Bloque ou débloque le compte (après confirmation pour un blocage).
Future<void> toggleUserBlocked(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final block = !user.isBlocked;
  if (block) {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Bloquer ${user.firstName} ?',
      message:
          "L'utilisateur ne pourra plus se connecter tant que son compte "
          'sera bloqué.',
      confirmLabel: 'Bloquer',
      icon: Icons.block_rounded,
    );
    if (!confirmed) return;
  }
  try {
    await ref
        .read(usersControllerProvider.notifier)
        .setStatus(user, block ? UserStatus.blocked : UserStatus.active);
    if (context.mounted) {
      AppSnackbar.success(
        context,
        block ? '${user.fullName} est bloqué' : '${user.fullName} est débloqué',
      );
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Change le rôle de l'utilisateur (choix dans une boîte de dialogue).
Future<void> changeUserRole(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final role = await pickRole(context, user);
  if (role == null) return;
  try {
    await ref.read(usersControllerProvider.notifier).setRole(user, role);
    if (context.mounted) {
      AppSnackbar.success(
        context,
        '${user.fullName} est maintenant ${role.label.toLowerCase()}',
      );
    }
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Actions du menu « ⋮ » du tableau. L'admin connecté ne peut pas se
/// bloquer ni changer son propre rôle.
List<AppTableAction<User>> userTableActions(
  BuildContext context,
  WidgetRef ref, {
  String? meId,
}) => [
  AppTableAction(
    label: 'Changer le rôle',
    icon: Icons.badge_outlined,
    isVisible: (u) => u.id != meId,
    onSelected: (u) => changeUserRole(context, ref, u),
  ),
  AppTableAction(
    label: 'Bloquer',
    icon: Icons.block_rounded,
    isDestructive: true,
    isVisible: (u) => !u.isBlocked && u.id != meId,
    onSelected: (u) => toggleUserBlocked(context, ref, u),
  ),
  AppTableAction(
    label: 'Débloquer',
    icon: Icons.lock_open_rounded,
    isVisible: (u) => u.isBlocked,
    onSelected: (u) => toggleUserBlocked(context, ref, u),
  ),
];
