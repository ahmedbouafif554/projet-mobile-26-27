import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_price.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/widgets/profile_icons.dart';
import '../../models/cart_item.dart';
import '../controllers/cart_controller.dart';
import '../controllers/orders_controller.dart';
import '../widgets/price_summary.dart';

/// Validation de commande : adresse, créneau, paiement et récapitulatif.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const _slots = [
    '12:30 – 13:00',
    '13:00 – 13:30',
    '19:00 – 19:30',
    '19:30 – 20:00',
  ];

  final _note = TextEditingController();
  bool _asap = true;
  String _slot = _slots.first;
  bool _placing = false;

  // Photo du panier prise à l'ouverture : la page reste identique
  // pendant la transition, même une fois le panier vidé.
  final CartController _cart = CartController.instance;
  late final List<CartItem> _items = _cart.items;
  late final double _subtotal = _cart.subtotal;
  late final double _deliveryFee = _cart.deliveryFee;
  late final double _serviceFee = _cart.serviceFee;
  late final double _discount = _cart.discount;
  late final double _total = _cart.total;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final profile = ProfileController.instance;
    setState(() => _placing = true);
    // Paiement simulé
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final order = OrdersController.instance.placeOrder(
      cart: _cart,
      address: profile.selectedAddress.fullAddress,
      paymentLabel: profile.selectedPayment.displayLabel,
    );
    context.go(AppRoutes.confirmationOf(order.id));
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: 68,
          leading: const Center(child: AppBackButton()),
        ),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Rien à valider',
          message: 'Votre panier est vide pour le moment.',
          actionLabel: "Retour à l'accueil",
          onAction: () => context.go(AppRoutes.home),
        ),
      );
    }

    final profile = ProfileController.instance;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Validation'),
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.sm,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children:
              [
                    _SectionTitle(
                      title: 'Adresse de livraison',
                      action: 'Gérer',
                      onAction: () => context.push(AppRoutes.addresses),
                    ),
                    for (final address in profile.addresses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SelectableTile(
                          icon: addressIcon(address.type),
                          title: address.label,
                          subtitle: address.fullAddress,
                          selected: address.id == profile.selectedAddress.id,
                          onTap: () => profile.selectAddress(address.id),
                        ),
                      ),
                    const _SectionTitle(title: 'Heure de livraison'),
                    Row(
                      children: [
                        SelectableChip(
                          label: 'Dès que possible',
                          icon: Icons.bolt_rounded,
                          selected: _asap,
                          onTap: () => setState(() => _asap = true),
                        ),
                        const SizedBox(width: 10),
                        SelectableChip(
                          label: 'Planifier',
                          icon: Icons.event_rounded,
                          selected: !_asap,
                          onTap: () => setState(() => _asap = false),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: AppDurations.medium,
                      curve: Curves.easeOutCubic,
                      child: _asap
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'Livraison estimée dans 25 à 35 minutes',
                                style: context.text.bodySmall,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final slot in _slots)
                                    SelectableChip(
                                      label: slot,
                                      selected: _slot == slot,
                                      onTap: () => setState(() => _slot = slot),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    _SectionTitle(
                      title: 'Paiement',
                      action: 'Gérer',
                      onAction: () => context.push(AppRoutes.paymentMethods),
                    ),
                    for (final method in profile.payments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SelectableTile(
                          icon: paymentIcon(method.type),
                          title: method.displayLabel,
                          subtitle: method.expiry == null
                              ? null
                              : 'Expire le ${method.expiry}',
                          selected: method.id == profile.selectedPayment.id,
                          onTap: () => profile.selectPayment(method.id),
                        ),
                      ),
                    const _SectionTitle(title: 'Note pour le livreur'),
                    AppTextField(
                      controller: _note,
                      hint: "Ex. : sonner à l'interphone, 3e étage…",
                      prefixIcon: Icons.chat_bubble_outline_rounded,
                      maxLines: 2,
                    ),
                    const _SectionTitle(title: 'Récapitulatif'),
                    _ItemsSummary(items: _items),
                    const SizedBox(height: 12),
                    PriceSummary(
                      subtotal: _subtotal,
                      deliveryFee: _deliveryFee,
                      serviceFee: _serviceFee,
                      discount: _discount,
                      total: _total,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: context.palette.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Paiement 100 % sécurisé (simulation, aucun débit réel).',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ]
                  .animate(interval: 30.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.08, end: 0),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.sm,
            AppSizes.pagePadding,
            AppSizes.md,
          ),
          child: PrimaryButton(
            label: 'Confirmer et payer',
            icon: Icons.lock_rounded,
            isLoading: _placing,
            trailing: AnimatedPrice(_total),
            onPressed: _placeOrder,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.lg, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Liste compacte des articles commandés.
class _ItemsSummary extends StatelessWidget {
  const _ItemsSummary({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: context.text.labelMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.product.name, style: context.text.labelLarge),
                        if (item.optionsLabel.isNotEmpty)
                          Text(
                            item.optionsLabel,
                            style: context.text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.price(item.totalPrice),
                    style: context.text.labelLarge,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
