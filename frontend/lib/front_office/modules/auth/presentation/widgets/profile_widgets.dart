import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/user.dart';
import '../../../../router/front_routes.dart';
import '../../providers/profile_providers.dart';

/// Tag Hero de la photo de profil (profil → modification).
const profileAvatarHeroTag = 'profile-avatar';

/// Retour des pages du compte : ramène au profil du rôle si la page a été
/// ouverte directement.
class AccountBackButton extends ConsumerWidget {
  const AccountBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authServiceProvider).role;
    return AppBackButton(
      fallbackRoute: role == null
          ? FrontRoutes.login
          : FrontRoutes.profileFor(role),
    );
  }
}

/// Photo ronde de l'utilisateur (initiales si pas de photo).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 64});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? ColoredBox(
                color: AppColors.primary.withValues(alpha: 0.15),
                child: Center(
                  child: Text(
                    user.initials,
                    style: context.text.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontSize: size * 0.32,
                    ),
                  ),
                ),
              )
            : AppNetworkImage(
                url,
                width: size,
                height: size,
                fallbackIcon: Icons.person_rounded,
              ),
      ),
    );
  }
}

/// Carte orange en haut du profil : photo, nom, coordonnées, rôle.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.user, this.onEdit});

  final User user;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onEdit,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md + 4),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: profileAvatarHeroTag,
              child: UserAvatar(user: user, size: 68),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.role == UserRole.courier
                              ? Icons.delivery_dining_rounded
                              : Icons.person_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.role.label,
                          style: context.text.labelMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trois chiffres clés sous la carte du profil.
class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileStatsProvider);
    return stats.when(
      loading: () => const ShimmerScope(
        child: Row(
          children: [
            Expanded(child: SkeletonBox(height: 72)),
            SizedBox(width: AppSizes.sm + 4),
            Expanded(child: SkeletonBox(height: 72)),
            SizedBox(width: AppSizes.sm + 4),
            Expanded(child: SkeletonBox(height: 72)),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) => Row(
        children: [
          for (final (i, (value, label)) in stats.items.indexed) ...[
            if (i > 0) const SizedBox(width: AppSizes.sm + 4),
            Expanded(
              child:
                  AppCard(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.md,
                          horizontal: AppSizes.sm,
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              child: Text(
                                value,
                                style: context.text.titleLarge?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      )
                      .animate(delay: (80 * i).ms)
                      .fadeIn(duration: 350.ms)
                      .scaleXY(begin: 0.9, end: 1),
            ),
          ],
        ],
      ),
    );
  }
}

/// Groupe d'options du profil : titre puis carte de lignes.
class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: AppSizes.sm),
          child: Text(
            title.toUpperCase(),
            style: context.text.labelMedium?.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(indent: 64, height: 1),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne d'option : icône colorée, titre, sous-titre et chevron.
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.primary,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.error : color;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Icon(icon, color: tint, size: 21),
      ),
      title: Text(
        title,
        style: context.text.titleSmall?.copyWith(
          color: destructive ? AppColors.error : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
      trailing:
          trailing ??
          (destructive
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.textSecondary,
                )),
    );
  }
}
