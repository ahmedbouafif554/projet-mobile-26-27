import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/avatar.dart';
import '../../shared/models/user.dart';
import '../router/back_routes.dart';
import 'back_nav.dart';

/// Largeurs de la sidebar.
class SidebarWidth {
  SidebarWidth._();

  static const double expanded = 264;
  static const double collapsed = 80;
}

/// Menu latéral du back office : logo, entrées groupées par module (filtrées
/// selon le rôle) avec compteurs, carte de l'utilisateur. Animé entre la
/// version dépliée et la version repliée (icônes seules).
class BackSidebar extends ConsumerWidget {
  const BackSidebar({
    super.key,
    required this.location,
    required this.collapsed,
    this.onToggle,
    this.onNavigate,
  });

  /// Chemin courant (entrée active).
  final String location;
  final bool collapsed;

  /// Replier / déplier (absent dans le Drawer mobile).
  final VoidCallback? onToggle;

  /// Appelé après un choix (ferme le Drawer sur mobile).
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).user;
    if (user == null) return const SizedBox.shrink();
    final groups = navFor(user.role);
    final active = navItemFor(location);

    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      width: collapsed ? SidebarWidth.collapsed : SidebarWidth.expanded,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(right: BorderSide(color: context.palette.border)),
      ),
      // Le contenu suit la largeur réelle (et non l'état demandé) : pendant
      // l'animation, les libellés n'apparaissent qu'une fois la place libre.
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 160;
            return Column(
              children: [
                _SidebarHeader(collapsed: narrow),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      for (final (gi, group) in groups.indexed) ...[
                        if (group.title != null)
                          _GroupTitle(title: group.title!, collapsed: narrow),
                        for (final (ii, item) in group.items.indexed)
                          _SidebarTile(
                                item: item,
                                role: user.role,
                                selected: identical(item, active),
                                collapsed: narrow,
                                onTap: () {
                                  onNavigate?.call();
                                  context.go(item.path);
                                },
                              )
                              .animate(delay: (30 * (gi + ii)).ms)
                              .fadeIn(duration: 300.ms)
                              .slideX(begin: -0.1, end: 0),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                _UserCard(
                  user: user,
                  collapsed: narrow,
                  selected: location == BackRoutes.account,
                  onTap: () {
                    onNavigate?.call();
                    context.go(BackRoutes.account);
                  },
                ),
                if (onToggle != null)
                  _CollapseButton(collapsed: narrow, onTap: onToggle!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    // Replié : le logo seul, centré (la bordure droite prend 1 px).
    if (collapsed) {
      return const SizedBox(
        height: 68,
        child: Center(child: AppLogo(size: 40)),
      );
    }
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const AppLogo(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Super',
                      style: context.text.titleMedium,
                      children: const [
                        TextSpan(
                          text: 'Faster',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  Text(
                    'Espace Pro',
                    maxLines: 1,
                    softWrap: false,
                    style: context.text.labelSmall?.copyWith(
                      color: context.palette.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title, required this.collapsed});

  final String title;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: collapsed
          ? Center(
              child: SizedBox(
                width: 24,
                child: Divider(color: context.palette.border, thickness: 2),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 12, top: 10),
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: context.text.labelSmall?.copyWith(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
    );
  }
}

/// Entrée du menu : fond teinté et barre orange quand elle est active,
/// compteur à droite (ou pastille sur l'icône quand la sidebar est repliée).
class _SidebarTile extends ConsumerWidget {
  const _SidebarTile({
    required this.item,
    required this.role,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final BackNavItem item;
  final UserRole role;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = item.badge?.call(ref, role) ?? 0;
    final label = item.labelFor(role);
    final color = selected ? AppColors.primary : context.palette.textSecondary;

    final icon = Badge(
      isLabelVisible: collapsed && count > 0,
      backgroundColor: AppColors.badge,
      label: Text('$count'),
      child: Icon(item.icon, color: color, size: 22),
    );

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: context.isDark ? 0.18 : 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 4,
                  height: selected ? 22 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                icon,
                if (!collapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: context.text.labelLarge?.copyWith(
                        color: selected
                            ? AppColors.primary
                            : context.colors.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (count > 0)
                    _CountPill(count: count, selected: selected)
                        .animate(key: ValueKey(count))
                        .scaleXY(begin: 0.6, curve: Curves.elasticOut),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return collapsed
        ? Tooltip(
            message: count > 0 ? '$label ($count)' : label,
            preferBelow: false,
            child: tile,
          )
        : tile;
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.badge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final User user;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: _MaybeTooltip(
        message: collapsed ? 'Mon compte' : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : context.palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Row(
              children: [
                Avatar(name: user.fullName, imageUrl: user.avatarUrl, size: 38),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          user.role.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.settings_rounded,
                    size: 18,
                    color: context.palette.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Tooltip(
        message: collapsed ? 'Déplier le menu' : 'Replier le menu',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 14),
                AnimatedRotation(
                  duration: AppDurations.medium,
                  turns: collapsed ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    color: context.palette.textSecondary,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Replier',
                    maxLines: 1,
                    softWrap: false,
                    style: context.text.labelLarge?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Info-bulle seulement si [message] est fourni.
class _MaybeTooltip extends StatelessWidget {
  const _MaybeTooltip({required this.message, required this.child});

  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      message == null ? child : Tooltip(message: message, child: child);
}
