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
import '../../../../../shared/repositories/repository_providers.dart';
import '../../domain/gift_order.dart';
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
  PaymentMethod _payment = PaymentMethod.available.first;
  bool _scheduled = false;
  String? _promoCode;
  double _discount = 0;
  String? _promoError;
  bool _paying = false;

  // ─── Commande Cadeau ───────────────────────────────────────────────────────
  bool _isGift = false;
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _recipientEmail = TextEditingController();
  final _senderName = TextEditingController();
  bool _isAnonymous = false;
  final _giftMessage = TextEditingController();
  GiftCardDesign _giftCardDesign = GiftCardDesign.festive;
  DateTime? _giftScheduledAt;

  // ─── Pourboire Livreur à la commande ───────────────────────────────────────
  double? _checkoutTipAmount;

  @override
  void dispose() {
    _promo.dispose();
    _note.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    _recipientEmail.dispose();
    _senderName.dispose();
    _giftMessage.dispose();
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

  Future<void> _saveGiftAndTip(String orderId) async {
    final repo = ref.read(orderRepositoryProvider);
    if (_isGift) {
      try {
        await repo.addGift(orderId, {
          'recipientName': _recipientName.text.trim(),
          if (_recipientPhone.text.trim().isNotEmpty)
            'recipientPhone': _recipientPhone.text.trim(),
          if (_recipientEmail.text.trim().isNotEmpty)
            'recipientEmail': _recipientEmail.text.trim(),
          if (!_isAnonymous && _senderName.text.trim().isNotEmpty)
            'senderName': _senderName.text.trim(),
          'isAnonymous': _isAnonymous,
          if (_giftMessage.text.trim().isNotEmpty)
            'message': _giftMessage.text.trim(),
          'giftCardDesign': _giftCardDesign.id,
          if (_giftScheduledAt != null)
            'scheduledAt': _giftScheduledAt!.toIso8601String(),
        });
      } catch (_) {}
    }
    if (_checkoutTipAmount != null && _checkoutTipAmount! > 0) {
      try {
        await repo.addTip(orderId, {
          'amount': _checkoutTipAmount!,
          'paymentMethod': _payment.name,
        });
      } catch (_) {}
    }
  }

  Future<void> _pickGiftSchedule() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 30),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _giftScheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pay(Address? address, CartTotals totals) async {
    if (address == null) {
      AppSnackbar.info(context, 'Ajoutez une adresse de livraison.');
      return;
    }

    if (_isGift && _recipientName.text.trim().isEmpty) {
      AppSnackbar.error(
        context,
        'Veuillez renseigner le nom du destinataire pour le cadeau.',
      );
      return;
    }

    final totalToPay = totals.total + (_checkoutTipAmount ?? 0);

    if (_payment == PaymentMethod.card) {
      // Feuille de paiement interactive Stripe Demo
      final router = GoRouter.of(context);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _StripePaymentSheet(
          amount: totalToPay,
          onPay: () async {
            // 1. Enregistrement de la commande
            final order = await ref
                .read(myOrdersProvider.notifier)
                .place(
                  address: address,
                  paymentMethod: PaymentMethod.card,
                  note: _note.text,
                  promoCode: _promoCode,
                  discount: _discount,
                );

            // Enregistrement cadeau & pourboire
            await _saveGiftAndTip(order.id);

            // 2. Création du PaymentIntent Stripe (REST)
            Map<String, dynamic> intent = {};
            try {
              intent = await ref
                  .read(orderRepositoryProvider)
                  .createPaymentIntent(order.id);
            } catch (_) {}

            // 3. Confirmation du paiement
            try {
              await ref
                  .read(orderRepositoryProvider)
                  .confirmPayment(
                    order.id,
                    paymentIntentId: intent['paymentIntentId'] as String?,
                  );
            } catch (_) {}

            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).pop();
            router.go(FrontRoutes.orderConfirmed(order.id));
          },
        ),
      );
      return;
    }

    // Paiement en espèces à la livraison
    setState(() => _paying = true);
    final router = GoRouter.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const _PaymentDialog(method: PaymentMethod.cash),
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      final order = await ref
          .read(myOrdersProvider.notifier)
          .place(
            address: address,
            paymentMethod: PaymentMethod.cash,
            note: _note.text,
            promoCode: _promoCode,
            discount: _discount,
          );
      await _saveGiftAndTip(order.id);
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
                              child: Text(
                                address == null ? 'Ajouter' : 'Changer',
                              ),
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
                                for (final method in PaymentMethod.available)
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
                          _buildGiftSection(context),
                          const SizedBox(height: AppSizes.lg),
                          _buildTipSection(context, totals.total),
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
                      : 'Payer ${Formatters.price(totals.total + (_checkoutTipAmount ?? 0))}',
                  icon: Icons.lock_rounded,
                  isLoading: _paying,
                  onPressed: items.isEmpty ? null : () => _pay(address, totals),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftSection(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5E7E), Color(0xFFFF9999)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Envoyer comme cadeau 🎁',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Prix masqués, carte & révélation QR',
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isGift,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _isGift = val),
              ),
            ],
          ),
          if (_isGift) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            TextField(
              controller: _recipientName,
              decoration: const InputDecoration(
                labelText: 'Nom du destinataire *',
                hintText: 'Ex: Sarah Ben Ali',
                prefixIcon: Icon(Icons.person_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recipientPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (optionnel)',
                      hintText: '06 12 34 56 78',
                      prefixIcon: Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _recipientEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optionnel)',
                      hintText: 'sarah@example.com',
                      prefixIcon: Icon(Icons.email_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_rounded, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expéditeur secret (anonyme) 🤫',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          'Votre nom ne sera pas révélé au destinataire',
                          style: context.text.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isAnonymous,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isAnonymous = val),
                  ),
                ],
              ),
            ),
            if (!_isAnonymous) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _senderName,
                decoration: const InputDecoration(
                  labelText: 'Votre nom d’expéditeur',
                  hintText: 'Ex: Karim ou Un(e) ami(e)',
                  prefixIcon: Icon(Icons.badge_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _giftMessage,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message personnalisé',
                hintText: 'Ex: Bon appétit ! Profite bien de cette surprise gourmande.',
                prefixIcon: Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thème de la carte cadeau numérique',
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final design in GiftCardDesign.values) ...[
                    GestureDetector(
                      onTap: () => setState(() => _giftCardDesign = design),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: design.colors),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _giftCardDesign == design ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            if (_giftCardDesign == design)
                              BoxShadow(
                                color: design.colors.first.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(design.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              design.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (_giftCardDesign == design) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_send_rounded, size: 18),
              label: Text(
                _giftScheduledAt == null
                    ? 'Programmer la livraison surprise (optionnel)'
                    : 'Prévu le ${Formatters.dateTime(_giftScheduledAt!)}',
              ),
              onPressed: _pickGiftSchedule,
              style: OutlinedButton.styleFrom(
                foregroundColor: _giftScheduledAt != null ? AppColors.primary : null,
                side: BorderSide(
                  color: _giftScheduledAt != null ? AppColors.primary : context.palette.border,
                ),
              ),
            ),
            if (_giftScheduledAt != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _giftScheduledAt = null),
                  child: const Text('Effacer la date', style: TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les prix des articles seront masqués sur le reçu et le QR code de révélation du destinataire.',
                      style: context.text.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipSection(BuildContext context, double orderTotal) {
    const tipOptions = [null, 1.0, 2.0, 3.0, 5.0];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pourboire livreur 🛵',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '100% reversé directement à votre livreur',
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_checkoutTipAmount != null && _checkoutTipAmount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${Formatters.price(_checkoutTipAmount!)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final tip in tipOptions)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _checkoutTipAmount = tip),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _checkoutTipAmount == tip
                              ? AppColors.primary
                              : context.palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _checkoutTipAmount == tip
                                ? AppColors.primary
                                : context.palette.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tip == null ? 'Aucun' : '${tip.toInt()} €',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _checkoutTipAmount == tip
                                  ? Colors.white
                                  : context.colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
      PaymentMethod.card => (
        Icons.credit_card_rounded,
        'Stripe Démo • CB, Visa, Mastercard',
      ),
      PaymentMethod.applePay => (
        Icons.phone_iphone_rounded,
        'Paiement express',
      ),
      PaymentMethod.cash => (Icons.payments_outlined, 'Espèces à la livraison'),
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

/// Feuille de paiement Stripe Démo pour le module Panier & Commande.
class _StripePaymentSheet extends StatefulWidget {
  const _StripePaymentSheet({
    required this.amount,
    required this.onPay,
  });

  final double amount;
  final Future<void> Function() onPay;

  @override
  State<_StripePaymentSheet> createState() => _StripePaymentSheetState();
}

class _StripePaymentSheetState extends State<_StripePaymentSheet> {
  final _cardNumber = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(text: '12/28');
  final _cvc = TextEditingController(text: '123');
  final _name = TextEditingController(text: 'Client Démo SuperFaster');

  bool _loading = false;
  String? _stepText;
  String? _error;

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _name.dispose();
    super.dispose();
  }

  void _fillTestCard() {
    setState(() {
      _cardNumber.text = '4242 4242 4242 4242';
      _expiry.text = '12/28';
      _cvc.text = '123';
      _name.text = 'Client Démo SuperFaster';
      _error = null;
    });
  }

  Future<void> _processPayment() async {
    final card = _cardNumber.text.replaceAll(' ', '');
    if (card.length < 16) {
      setState(() => _error = 'Numéro de carte incomplet (16 chiffres requis).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _stepText = 'Connexion à Stripe API...';
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _stepText = 'Création du PaymentIntent Stripe...');
      
      await widget.onPay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _stepText = null;
        _error = 'Échec du paiement : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const stripeIndigo = Color(0xFF635BFF);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: stripeIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: stripeIndigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Stripe Payments',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: stripeIndigo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TEST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total à payer : ${Formatters.price(widget.amount)}',
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _loading ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: context.text.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Formulaire Carte
            Text(
              'Informations de la carte',
              style: context.text.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cardNumber,
              enabled: !_loading,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Numéro de carte',
                hintText: '4242 4242 4242 4242',
                prefixIcon: const Icon(
                  Icons.payment_rounded,
                  color: stripeIndigo,
                ),
                suffixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerRight,
                  width: 50,
                  child: const Text(
                    'VISA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: stripeIndigo,
                      fontSize: 12,
                    ),
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiry,
                    enabled: !_loading,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Expiration',
                      hintText: 'MM/AA',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cvc,
                    enabled: !_loading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      hintText: '123',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'Nom sur la carte',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton auto-remplir
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : _fillTestCard,
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Remplir la carte de test Stripe (4242)'),
                style: TextButton.styleFrom(
                  foregroundColor: stripeIndigo,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Bouton payer
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: stripeIndigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _stepText ?? 'Paiement en cours…',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Payer ${Formatters.price(widget.amount)} avec Stripe',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Paiement sécurisé crypté de bout en bout (Stripe API v2024)',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
