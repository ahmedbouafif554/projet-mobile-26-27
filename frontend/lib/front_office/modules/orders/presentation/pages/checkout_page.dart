import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../../auth/providers/addresses_controller.dart';
import '../../../catalog/providers/catalog_providers.dart';
import '../../providers/cart_controller.dart';
import '../../providers/orders_providers.dart';
import '../widgets/order_widgets.dart';

/// Validation de la commande : adresse, moment de livraison, paiement, code
/// promo, note pour le livreur, puis paiement simulé.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _promo = TextEditingController();
  final _note = TextEditingController();
  String? _addressId;
  PaymentMethod _payment = PaymentMethod.card;
  bool _scheduled = false;
  String? _promoCode;
  double _discount = 0;
  String? _promoError;
  bool _paying = false;

  @override
  void dispose() {
    _promo.dispose();
    _note.dispose();
    super.dispose();
  }

  void _applyPromo(double subtotal, double deliveryFee) {
    final code = _promo.text.trim().toUpperCase();
    final discount = PromoCodes.discountFor(code, subtotal, deliveryFee);
    setState(() {
      if (discount == null || discount <= 0) {
        _promoError = 'Code invalide. ${PromoCodes.hint}.';
        _promoCode = null;
        _discount = 0;
      } else {
        _promoError = null;
        _promoCode = code;
        _discount = discount;
      }
    });
    if (discount != null && discount > 0) {
      FocusScope.of(context).unfocus();
      AppSnackbar.success(
        context,
        'Code $code appliqué : -${Formatters.price(discount)}',
      );
    }
  }

  Future<void> _pay(Address? address) async {
    if (address == null) {
      AppSnackbar.info(context, 'Ajoutez une adresse de livraison.');
      return;
    }
    setState(() => _paying = true);
    final router = GoRouter.of(context);
    // Paiement simulé : animation de traitement puis création de la commande.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _PaymentDialog(method: _payment),
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      final order = await ref
          .read(myOrdersProvider.notifier)
          .place(
            address: address,
            paymentMethod: _payment,
            note: _note.text,
            promoCode: _promoCode,
            discount: _discount,
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      router.go(FrontRoutes.orderConfirmed(order.id));
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _paying = false);
      AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartProvider).value ?? const <CartItem>[];
    final addresses = ref.watch(addressesProvider).value ?? const <Address>[];
    final restaurantId = items.firstOrNull?.product.restaurantId;
    final restaurant = restaurantId == null
        ? null
        : ref.watch(restaurantProvider(restaurantId)).value;
    final address =
        addresses.where((a) => a.id == _addressId).firstOrNull ??
        addresses.firstOrNull;
    final totals = CartTotals.of(items, restaurant, discount: _discount);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.sm,
              ),
              child: PageTitle('Paiement'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.sm,
                  AppSizes.pagePadding,
                  AppSizes.lg,
                ),
                children:
                    [
                          TitledBlock(
                            title: 'Adresse de livraison',
                            trailing: TextButton(
                              onPressed: () => _pickAddress(addresses),
                              child: Text(address == null ? 'Ajouter' : 'Changer'),
                            ),
                            child: SurfaceCard(
                              onTap: () => _pickAddress(addresses),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: address == null
                                        ? const Text(
                                            'Aucune adresse enregistrée',
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                address.label,
                                                style: context.text.titleSmall,
                                              ),
                                              Text(
                                                address.fullAddress,
                                                style: context.text.bodySmall
                                                    ?.copyWith(
                                                      color: context
                                                          .palette
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.lg),
                          TitledBlock(
                            title: 'Livraison',
                            child: SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: false,
                                  icon: const Icon(Icons.bolt_rounded),
                                  label: Text(
                                    'Dès que possible${restaurant == null ? '' : ' (${restaurant.deliveryTimeLabel})'}',
                                  ),
                                ),
                                const ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.schedule_rounded),
                                  label: Text('Plus tard'),
                                ),
                              ],
                              selected: {_scheduled},
                              onSelectionChanged: (s) {
                                setState(() => _scheduled = s.first);
                                if (s.first) {
                                  AppSnackbar.info(
                                    context,
                                    'Livraison programmée dans 1 h (démo).',
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSizes.lg),
                          TitledBlock(
                            title: 'Moyen de paiement',
                            child: Column(
                              children: [
                                for (final method in PaymentMethod.values)
                                  _PaymentTile(
                                    method: method,
                                    selected: method == _payment,
                                    onTap: () =>
                                        setState(() => _payment = method),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.lg),
                          TitledBlock(
                            title: 'Code promo',
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _promo,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'SUPER10',
                                      prefixIcon: const Icon(
                                        Icons.local_offer_outlined,
                                      ),
                                      errorText: _promoError,
                                      errorMaxLines: 2,
                                      suffixIcon: _promoCode == null
                                          ? null
                                          : const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.success,
                                            ),
                                    ),
                                    onSubmitted: (_) => _applyPromo(
                                      totals.subtotal,
                                      totals.deliveryFee,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.sm),
                                SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 56),
                                    ),
                                    onPressed: () => _applyPromo(
                                      totals.subtotal,
                                      totals.deliveryFee,
                                    ),
                                    child: const Text('Appliquer'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.lg),
                          TitledBlock(
                            title: 'Note pour le livreur',
                            child: TextField(
                              controller: _note,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Digicode, étage, sonner fort…',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.lg),
                          TotalsCard(totals: totals, promoCode: _promoCode),
                        ]
                        .animate(interval: 40.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.06, end: 0),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.sm + 4,
                AppSizes.pagePadding,
                AppSizes.sm + 4,
              ),
              decoration: BoxDecoration(
                color: context.colors.surface,
                boxShadow: [
                  BoxShadow(
                    color: context.palette.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: PrimaryButton(
                  label: _payment == PaymentMethod.cash
                      ? 'Commander'
                      : 'Payer ${Formatters.price(totals.total)}',
                  icon: Icons.lock_rounded,
                  isLoading: _paying,
                  onPressed: items.isEmpty ? null : () => _pay(address),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAddress(List<Address> addresses) async {
    if (addresses.isEmpty) {
      await context.push(FrontRoutes.addresses);
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding,
              ),
              child: Text('Livrer à', style: context.text.titleLarge),
            ),
            const SizedBox(height: AppSizes.sm),
            for (final a in addresses)
              RadioListTile<String>(
                value: a.id,
                groupValue: _addressId ?? addresses.first.id,
                activeColor: AppColors.primary,
                title: Text(a.label),
                subtitle: Text(a.fullAddress),
                onChanged: (id) => Navigator.pop(context, id),
              ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Gérer mes adresses'),
              onTap: () => Navigator.pop(context, ''),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked.isEmpty) {
      await context.push(FrontRoutes.addresses);
    } else {
      setState(() => _addressId = picked);
    }
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, detail) = switch (method) {
      PaymentMethod.card => (Icons.credit_card_rounded, 'Visa •••• 4242'),
      PaymentMethod.applePay => (Icons.phone_iphone_rounded, 'Paiement express'),
      PaymentMethod.cash => (Icons.payments_outlined, 'À la livraison'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : context.colors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : context.palette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.primary : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method.label, style: context.text.titleSmall),
                    Text(
                      detail,
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  key: ValueKey(selected),
                  color: selected
                      ? AppColors.primary
                      : context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paiement en cours : carte qui pulse puis texte « Paiement sécurisé ».
class _PaymentDialog extends StatelessWidget {
  const _PaymentDialog({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      method == PaymentMethod.cash
                          ? Icons.receipt_long_rounded
                          : Icons.credit_card_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.92, end: 1.06, duration: 600.ms),
              const SizedBox(height: AppSizes.lg),
              Text(
                method == PaymentMethod.cash
                    ? 'Envoi de la commande…'
                    : 'Paiement en cours…',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Connexion sécurisée 🔒',
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              const LinearProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
