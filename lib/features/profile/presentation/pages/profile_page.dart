import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../catalog/presentation/controllers/favorites_controller.dart';
import '../../../communication/communication_routes.dart';
import '../../../communication/presentation/controllers/conversations_controller.dart';
import '../../../communication/presentation/controllers/notification_center_controller.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../data/profile_mock_data.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_menu_tile.dart';
import '../widgets/theme_selector.dart';

/// Onglet Profil : informations, raccourcis et préférences.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.error,
          size: 32,
        ),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous reconnecter pour passer commande.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(130, 44),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppSession.instance.logout();
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    final favorites = FavoritesController.instance;
    final orders = OrdersController.instance;
    final notifications = NotificationCenterController.instance;
    final conversations = ConversationsController.instance;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            profile,
            favorites,
            orders,
            notifications,
            conversations,
          ]),
          builder: (context, _) {
            final user = profile.user;
            final language = ProfileMockData.languages.firstWhere(
              (l) => l.code == profile.languageCode,
            );
            final orderCount =
                orders.activeOrders.length + orders.pastOrders.length;

            return ListView(
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
                        // Carte utilisateur
                        Pressable(
                          onTap: () => context.push(AppRoutes.editProfile),
                          scale: 0.98,
                          child: Container(
                            padding: const EdgeInsets.all(AppSizes.md),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusXl,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: AppNetworkImage(
                                      user.avatarUrl,
                                      width: 62,
                                      height: 62,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: context.text.titleLarge
                                            ?.copyWith(color: Colors.white),
                                      ),
                                      Text(
                                        user.email,
                                        style: context.text.bodySmall?.copyWith(
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        user.phone,
                                        style: context.text.bodySmall?.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSm,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        // Statistiques
                        Row(
                          children: [
                            _StatTile(
                              value: '$orderCount',
                              label: 'Commandes',
                              onTap: () => context.go(AppRoutes.orders),
                            ),
                            const SizedBox(width: 12),
                            _StatTile(
                              value: '${favorites.count}',
                              label: 'Favoris',
                              onTap: () => context.push(AppRoutes.favorites),
                            ),
                            const SizedBox(width: 12),
                            _StatTile(
                              value: '${user.loyaltyPoints}',
                              label: 'Points',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),
                        ProfileMenuSection(
                          title: 'Mon compte',
                          children: [
                            ProfileMenuTile(
                              icon: Icons.person_outline_rounded,
                              title: 'Informations personnelles',
                              subtitle: 'Nom, e-mail, téléphone',
                              onTap: () => context.push(AppRoutes.editProfile),
                            ),
                            ProfileMenuTile(
                              icon: Icons.location_on_outlined,
                              title: 'Mes adresses',
                              subtitle:
                                  '${profile.addresses.length} adresses enregistrées',
                              color: AppColors.info,
                              onTap: () => context.push(AppRoutes.addresses),
                            ),
                            ProfileMenuTile(
                              icon: Icons.credit_card_rounded,
                              title: 'Moyens de paiement',
                              subtitle: profile.selectedPayment.displayLabel,
                              color: AppColors.success,
                              onTap: () =>
                                  context.push(AppRoutes.paymentMethods),
                            ),
                            ProfileMenuTile(
                              icon: Icons.favorite_border_rounded,
                              title: 'Mes favoris',
                              subtitle: '${favorites.count} restaurants',
                              color: AppColors.favorite,
                              onTap: () => context.push(AppRoutes.favorites),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),
                        ProfileMenuSection(
                          title: 'Communication',
                          children: [
                            ProfileMenuTile(
                              icon: Icons.forum_outlined,
                              title: 'Messages',
                              subtitle: 'Restaurants, livreurs et support',
                              color: AppColors.info,
                              onTap: () =>
                                  context.push(CommunicationRoutes.chats),
                              trailing: _CountBadge(
                                count: conversations.totalUnread,
                              ),
                            ),
                            ProfileMenuTile(
                              icon: Icons.notifications_none_rounded,
                              title: 'Notifications',
                              subtitle: 'Centre de notifications',
                              color: AppColors.warning,
                              onTap: () => context.push(
                                CommunicationRoutes.notifications,
                              ),
                              trailing: _CountBadge(
                                count: notifications.unreadCount,
                              ),
                            ),
                            ProfileMenuTile(
                              icon: Icons.tune_rounded,
                              title: 'Réglages des notifications',
                              subtitle: 'Par type, bannières, ne pas déranger',
                              color: AppColors.warning,
                              onTap: () => context.push(
                                CommunicationRoutes.notificationSettings,
                              ),
                            ),
                            ProfileMenuTile(
                              icon: Icons.rate_review_outlined,
                              title: 'Mes avis',
                              subtitle: 'Notes et commentaires publiés',
                              color: AppColors.primary,
                              onTap: () =>
                                  context.push(CommunicationRoutes.myReviews),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),
                        ProfileMenuSection(
                          title: 'Préférences',
                          children: [
                            ProfileMenuTile(
                              icon: Icons.language_rounded,
                              title: 'Langue',
                              subtitle: '${language.flag}  ${language.name}',
                              color: AppColors.info,
                              onTap: () => context.push(AppRoutes.language),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSizes.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusSm,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.palette_outlined,
                                          color: context.colors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Thème',
                                        style: context.text.titleSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const ThemeSelector(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),
                        ProfileMenuSection(
                          title: 'Plus',
                          children: [
                            ProfileMenuTile(
                              icon: Icons.local_shipping_outlined,
                              title: 'Envoyer un colis',
                              subtitle: 'Coursier express en ville',
                              color: const Color(0xFF6366F1),
                              onTap: () => context.push(AppRoutes.parcel),
                            ),
                            ProfileMenuTile(
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'Espace administrateur',
                              subtitle: 'Tableau de bord (démo)',
                              color: AppColors.secondary,
                              onTap: () => context.push(AppRoutes.admin),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),
                        Pressable(
                          onTap: () => _logout(context),
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Se déconnecter',
                                  style: context.text.titleSmall?.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Center(
                          child: Text(
                            'SuperFaster v1.0.0 • Démo frontend',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            );
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: context.palette.softShadow,
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: AppDurations.medium,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: context.text.titleLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(label, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de compteur (rien si zéro), qui rebondit quand le nombre change.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Icon(
        Icons.chevron_right_rounded,
        color: context.palette.textSecondary,
      );
    }
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.favorite,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: context.text.labelMedium?.copyWith(color: Colors.white),
          ),
        )
        .animate(key: ValueKey(count))
        .scaleXY(
          begin: 0.4,
          end: 1,
          duration: 500.ms,
          curve: Curves.elasticOut,
        );
  }
}
