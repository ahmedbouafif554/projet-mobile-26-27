import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../shared/models/user.dart';
import '../router/back_routes.dart';
import 'back_alerts.dart';
import 'back_nav.dart';
import 'global_search.dart';

/// Barre du haut : menu / repli de la sidebar, recherche globale, thème,
/// alertes et menu du compte.
class BackTopbar extends ConsumerWidget {
  const BackTopbar({
    super.key,
    required this.location,
    required this.compact,
    required this.onMenu,
  });

  final String location;

  /// Téléphone : bouton menu (Drawer), titre de la page, recherche en icône.
  final bool compact;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).user;
    if (user == null) return const SizedBox.shrink();
    final item = navItemFor(location);
    final title = location == BackRoutes.account
        ? 'Mon compte'
        : item?.labelFor(user.role) ?? 'Espace Pro';

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              tooltip: 'Menu',
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge,
              ),
            ),
            const GlobalSearch(iconOnly: true),
          ] else ...[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: const SizedBox(
                    width: double.infinity,
                    child: GlobalSearch(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            const _ThemeButton(),
          ],
          _AlertsBell(role: user.role),
          const SizedBox(width: 4),
          _AccountMenu(user: user, compact: compact),
        ],
      ),
    );
  }
}

class _ThemeButton extends ConsumerWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    return IconButton(
      tooltip: dark ? 'Thème clair' : 'Thème sombre',
      onPressed: ref.read(themeModeProvider.notifier).toggle,
      icon: AnimatedSwitcher(
        duration: AppDurations.medium,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.6, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(dark),
        ),
      ),
    );
  }
}

/// Cloche : nombre total d'alertes et liste des éléments à traiter.
class _AlertsBell extends ConsumerWidget {
  const _AlertsBell({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = watchAlerts(ref, role);
    final total = alerts.fold(0, (sum, a) => sum + a.count);

    return MenuAnchor(
      alignmentOffset: const Offset(-260, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
      ),
      menuChildren: [
        SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                Text('Alertes', style: context.text.titleMedium),
                const Spacer(),
                if (total > 0)
                  Text(
                    '$total à traiter',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (alerts.isEmpty)
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tout est à jour, rien à traiter.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final alert in alerts)
            MenuItemButton(
              onPressed: () => context.go(alert.route),
              leadingIcon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: alert.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(alert.icon, color: alert.color, size: 20),
              ),
              trailingIcon: Icon(
                Icons.chevron_right_rounded,
                color: context.palette.textSecondary,
              ),
              child: SizedBox(
                width: 210,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(alertLabel(alert)),
                ),
              ),
            ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Alertes',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          isLabelVisible: total > 0,
          backgroundColor: AppColors.badge,
          label: Text('$total'),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ).animate(key: ValueKey(total)).shake(
        hz: 4,
        rotation: total > 0 ? 0.08 : 0,
        duration: 500.ms,
      ),
    );
  }
}

/// Avatar et menu du compte : mon compte, thème, déconnexion.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.user, required this.compact});

  final User user;
  final bool compact;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous devrez saisir à nouveau vos identifiants.',
      confirmLabel: 'Déconnexion',
      icon: Icons.logout_rounded,
    );
    if (confirmed) ref.read(authServiceProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Avatar(name: user.fullName, imageUrl: user.avatarUrl, size: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: context.text.titleSmall),
                  Text(
                    user.email,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.manage_accounts_rounded),
          onPressed: () => context.go(BackRoutes.account),
          child: const Text('Mon compte'),
        ),
        if (compact)
          MenuItemButton(
            leadingIcon: Icon(
              context.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: ref.read(themeModeProvider.notifier).toggle,
            child: Text(context.isDark ? 'Thème clair' : 'Thème sombre'),
          ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout_rounded, color: AppColors.error),
          onPressed: () => _logout(context, ref),
          child: const Text(
            'Déconnexion',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
      builder: (context, controller, _) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(name: user.fullName, imageUrl: user.avatarUrl, size: 36),
              if (!compact) ...[
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.firstName, style: context.text.titleSmall),
                    Text(
                      user.role.label,
                      style: context.text.labelSmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.expand_more_rounded,
                  color: context.palette.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
