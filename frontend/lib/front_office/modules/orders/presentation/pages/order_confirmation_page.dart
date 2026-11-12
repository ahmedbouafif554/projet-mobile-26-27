import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/constants/app_assets.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../router/front_routes.dart';
import '../../providers/orders_providers.dart';
import '../../providers/gift_tip_providers.dart';

/// Confirmation animée après le paiement.
class OrderConfirmationPage extends ConsumerWidget {
  const OrderConfirmationPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).value;
    final gift = ref.watch(orderGiftProvider(orderId)).value;
    final eta = DateTime.now().add(const Duration(minutes: 30));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            children: [
              const Spacer(),
              Lottie.asset(
                AppAssets.lottieSuccess,
                width: 200,
                height: 200,
                repeat: false,
              ),
              Text(
                'Commande confirmée !',
                textAlign: TextAlign.center,
                style: context.text.headlineMedium,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),
              const SizedBox(height: AppSizes.sm),
              Text(
                order == null
                    ? 'Le restaurant a bien reçu votre commande.'
                    : 'Commande #${order.reference} chez ${order.restaurantName}.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: AppSizes.lg),
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arrivée estimée',
                            style: context.text.bodySmall?.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                          Text(
                            'vers ${Formatters.time(eta)}',
                            style: context.text.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    if (order != null)
                      Text(
                        Formatters.price(order.total),
                        style: context.text.titleMedium,
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).scaleXY(begin: 0.95),
              if (gift != null) ...[
                const SizedBox(height: AppSizes.md),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gift.giftCardDesign.colors),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: gift.giftCardDesign.colors.first.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(gift.giftCardDesign.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cadeau pour ${gift.recipientName} 🎁',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'QR code de révélation & prix masqués prêts',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => context.push('/gift-reveal/${gift.qrCode}'),
                        child: const Text('Voir le QR', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 750.ms).slideY(begin: 0.1, end: 0),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Suivre ma commande',
                icon: Icons.map_rounded,
                onPressed: () => context.go(FrontRoutes.orderTracking(orderId)),
              ),
              const SizedBox(height: AppSizes.sm),
              TextButton(
                onPressed: () => context.go(FrontRoutes.explore),
                child: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
