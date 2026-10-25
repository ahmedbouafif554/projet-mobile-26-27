import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../shared/models/user.dart';
import '../../../../router/front_routes.dart';
import '../../../communication/providers/communication_providers.dart';
import '../../providers/addresses_controller.dart';
import '../widgets/profile_widgets.dart';

/// Profil (onglet du client et du livreur) : carte utilisateur, chiffres
/// clés et accès au compte, aux paramètres et à la déconnexion.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  /// Demande confirmation puis ferme la session (le routeur affiche la
  /// connexion).
  static Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
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
    final user = ref.watch(authServiceProvider).user;
    if (user == null) return const Scaffold();
    final isClient = user.role == UserRole.client;
    final addresses = isClient ? ref.watch(addressesProvider).value : null;

    final unread = ref.watch(
      notificationsProvider.select(
        (n) => n.value?.where((x) => !x.isRead).length ?? 0,
      ),
    );

    /// Ouvre (ou crée) la conversation avec le support.
    Future<void> support() async {
      try {
        final chat = await ref.read(myChatsProvider.notifier).supportChat();
        if (!context.mounted) return;
        context.push(
          isClient ? FrontRoutes.chat(chat.id) : FrontRoutes.courierChat(chat.id),
        );
      } catch (error) {
        if (context.mounted) AppSnackbar.error(context, error);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children:
              [
                    const PageTitle('Profil'),
                    const SizedBox(height: AppSizes.lg),
                    ProfileHeaderCard(
                      user: user,
                      onEdit: () => context.push(FrontRoutes.editProfile),
                    ),
                    const SizedBox(height: AppSizes.md),
                    const ProfileStatsRow(),
                    const SizedBox(height: AppSizes.lg),
                    ProfileMenuSection(
                      title: 'Mon compte',
                      children: [
                        ProfileMenuTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Informations personnelles',
                          subtitle: 'Nom, e-mail, téléphone',
                          onTap: () => context.push(FrontRoutes.editProfile),
                        ),
                        if (isClient)
                          ProfileMenuTile(
                            icon: Icons.location_on_outlined,
                            color: AppColors.info,
                            title: 'Mes adresses',
                            subtitle: addresses == null
                                ? null
                                : '${addresses.length} adresse${addresses.length > 1 ? 's' : ''} enregistrée${addresses.length > 1 ? 's' : ''}',
                            onTap: () => context.push(FrontRoutes.addresses),
                          ),
                        if (isClient) ...[
                          ProfileMenuTile(
                            icon: Icons.favorite_outline_rounded,
                            color: AppColors.favorite,
                            title: 'Mes favoris',
                            onTap: () => context.push(FrontRoutes.favorites),
                          ),
                          ProfileMenuTile(
                            icon: Icons.rate_review_outlined,
                            color: AppColors.warning,
                            title: 'Mes avis',
                            onTap: () => context.push(FrontRoutes.myReviews),
                          ),
                        ] else
                          ProfileMenuTile(
                            icon: Icons.badge_outlined,
                            color: AppColors.success,
                            title: 'Documents et véhicule',
                            subtitle: "Pièce d'identité, permis, assurance",
                            onTap: () => context.push(FrontRoutes.documents),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    ProfileMenuSection(
                      title: 'Communication',
                      children: [
                        ProfileMenuTile(
                          icon: Icons.notifications_none_rounded,
                          color: AppColors.primary,
                          title: 'Notifications',
                          subtitle: unread == 0
                              ? 'Tout est lu'
                              : '$unread non lue${unread > 1 ? 's' : ''}',
                          onTap: () => context.push(FrontRoutes.notifications),
                        ),
                        if (isClient)
                          ProfileMenuTile(
                            icon: Icons.forum_outlined,
                            color: AppColors.info,
                            title: 'Messages',
                            subtitle: 'Restaurants, livreurs et support',
                            onTap: () => context.push(FrontRoutes.messages),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    ProfileMenuSection(
                      title: 'Application',
                      children: [
                        ProfileMenuTile(
                          icon: Icons.settings_outlined,
                          color: context.palette.textSecondary,
                          title: 'Paramètres',
                          subtitle: 'Thème, langue, notifications',
                          onTap: () => context.push(FrontRoutes.settings),
                        ),
                        ProfileMenuTile(
                          icon: Icons.support_agent_rounded,
                          color: AppColors.warning,
                          title: 'Aide et support',
                          subtitle: 'Discuter avec notre équipe',
                          onTap: support,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    ProfileMenuSection(
                      title: 'Session',
                      children: [
                        ProfileMenuTile(
                          icon: Icons.logout_rounded,
                          title: 'Déconnexion',
                          destructive: true,
                          onTap: () => confirmLogout(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Text(
                      'SuperFaster • version 1.0.0',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                  ]
                  .animate(interval: 50.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.08, end: 0),
        ),
      ),
    );
  }
}
