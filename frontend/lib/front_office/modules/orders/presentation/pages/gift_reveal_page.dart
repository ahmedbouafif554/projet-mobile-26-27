import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../domain/gift_order.dart';
import '../../providers/gift_tip_providers.dart';
import '../widgets/order_widgets.dart';
import '../widgets/qr_gift_card.dart';

/// Page de révélation d'un cadeau via QR code.
/// Masque les prix des produits pour préserver la surprise et l'élégance du cadeau.
class GiftRevealPage extends ConsumerStatefulWidget {
  const GiftRevealPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<GiftRevealPage> createState() => _GiftRevealPageState();
}

class _GiftRevealPageState extends ConsumerState<GiftRevealPage> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final revealAsync = ref.watch(revealGiftProvider(widget.token));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadeau SuperFaster 🎁'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: revealAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Révélation de votre surprise…'),
              ],
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cadeau introuvable',
                    style: context.text.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ce QR code est invalide ou a expiré.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Retour',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final giftData = data['gift'] as Map<String, dynamic>? ?? {};
            final orderData = data['order'] as Map<String, dynamic>? ?? {};
            final items = (data['items'] as List?) ?? [];

            final gift = GiftOrder.fromJson(giftData);
            final restaurantName =
                (orderData['restaurantName'] ?? 'Un restaurant partenaire') as String;

            if (!_revealed) {
              return _UnopenedGiftView(
                gift: gift,
                onOpen: () => setState(() => _revealed = true),
              );
            }

            return _RevealedGiftView(
              gift: gift,
              restaurantName: restaurantName,
              items: items,
            );
          },
        ),
      ),
    );
  }
}

class _UnopenedGiftView extends StatelessWidget {
  const _UnopenedGiftView({required this.gift, required this.onOpen});

  final GiftOrder gift;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vous avez reçu un cadeau ! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'De la part de : ${gift.effectiveSender}',
              style: context.text.bodyLarge?.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gift.giftCardDesign.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gift.giftCardDesign.colors.first.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 900.ms),
            ),
            const SizedBox(height: 36),
            Text(
              'Touchez la boîte pour déballer votre surprise',
              style: context.text.bodySmall?.copyWith(
                color: context.palette.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 260,
              child: PrimaryButton(
                label: 'Ouvrir mon cadeau 🎁',
                onPressed: onOpen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealedGiftView extends StatelessWidget {
  const _RevealedGiftView({
    required this.gift,
    required this.restaurantName,
    required this.items,
  });

  final GiftOrder gift;
  final String restaurantName;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        // Carte cadeau numérique
        DigitalGiftCardWidget(gift: gift, showQr: false)
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: AppSizes.lg),

        // Détails du festin offert avec prix soigneusement masqués
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre menu offert',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Préparé par $restaurantName',
                          style: context.text.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Prix masqués 🎁',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              for (final rawItem in items) ...[
                Builder(
                  builder: (ctx) {
                    final item = rawItem as Map;
                    final name = item['name'] as String? ?? 'Article';
                    final qty = item['quantity'] ?? 1;
                    final options = (item['options'] as List?) ?? [];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.palette.surfaceMuted,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$qty×',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (options.isNotEmpty)
                                  Text(
                                    options.join(' • '),
                                    style: ctx.text.bodySmall?.copyWith(
                                      color: ctx.palette.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 18,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: AppSizes.xl),

        Center(
          child: Text(
            'Ce cadeau est offert par ${gift.effectiveSender}. Bon appétit !',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
