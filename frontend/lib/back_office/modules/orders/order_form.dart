import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/models/models.dart';
import '../catalog/catalog_controllers.dart';
import 'orders_controller.dart';

/// Commande saisie à la main (commande par téléphone).
Future<bool> openOrderForm(BuildContext context) =>
    showAppForm(context, const OrderForm());

/// Frais de service appliqués aux commandes.
const double serviceFee = 0.99;

class OrderForm extends ConsumerStatefulWidget {
  const OrderForm({super.key});

  @override
  ConsumerState<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<OrderForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _postal = TextEditingController(text: '75011');
  final _city = TextEditingController(text: 'Paris');
  final _note = TextEditingController();
  late String? _restaurantId = ref
      .read(productsControllerProvider.notifier)
      .scope;
  PaymentMethod _payment = PaymentMethod.cash;

  /// Quantité par identifiant de produit.
  final Map<String, int> _quantities = {};

  @override
  void dispose() {
    for (final c in [_name, _phone, _street, _postal, _city, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Restaurant restaurant, List<Product> products) {
    final now = DateTime.now();
    final note = _note.text.trim();
    final items = [
      for (final p in products)
        if ((_quantities[p.id] ?? 0) > 0)
          CartItem(id: p.id, product: p, quantity: _quantities[p.id]!),
    ];
    return ref
        .read(ordersControllerProvider.notifier)
        .save(
          Order(
            id: '',
            reference: '',
            userId: 'guest',
            customerName: _name.text.trim(),
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            items: items,
            deliveryAddress: Address(
              id: '',
              userId: 'guest',
              label: 'Livraison',
              street: _street.text.trim(),
              postalCode: _postal.text.trim(),
              city: _city.text.trim(),
              instructions: 'Tél. ${_phone.text.trim()}',
            ),
            deliveryFee: restaurant.deliveryFee,
            serviceFee: serviceFee,
            paymentMethod: _payment,
            paymentStatus: _payment == PaymentMethod.cash
                ? PaymentStatus.pending
                : PaymentStatus.paid,
            note: note.isEmpty ? null : note,
            history: [
              OrderStatusEvent(
                status: OrderStatus.pending,
                at: now,
                note: 'Commande saisie par téléphone',
              ),
            ],
            createdAt: now,
          ),
          isNew: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurateur =
        ref.watch(authServiceProvider).role == UserRole.restaurant;
    final restaurants = (ref.watch(restaurantsControllerProvider).value ?? [])
        .where((r) => r.isVisible)
        .toList();
    final restaurant = restaurants
        .where((r) => r.id == _restaurantId)
        .firstOrNull;
    final products = (ref.watch(productsControllerProvider).value ?? [])
        .where((p) => p.restaurantId == _restaurantId && p.isAvailable)
        .toList();
    final subtotal = products.fold<double>(
      0,
      (s, p) => s + p.price * (_quantities[p.id] ?? 0),
    );
    final itemCount = _quantities.values.fold(0, (s, q) => s + q);

    return AppForm(
      title: 'Commande manuelle',
      subtitle: 'Saisie d’une commande passée par téléphone.',
      icon: Icons.add_call,
      submitLabel: 'Créer la commande',
      successMessage: 'Commande créée',
      onSubmit: () => _save(restaurant!, products),
      children: [
        if (!isRestaurateur)
          AppDropdownField<String>(
            label: 'Restaurant',
            prefixIcon: Icons.storefront_outlined,
            value: restaurant?.id,
            items: [for (final r in restaurants) r.id],
            itemLabel: (id) => restaurants.firstWhere((r) => r.id == id).name,
            onChanged: (id) => setState(() {
              _restaurantId = id;
              _quantities.clear();
            }),
            validator: (id) => id == null ? 'Choisissez le restaurant' : null,
          ),
        const AppFormSection(title: 'Client'),
        AppFormRow(
          children: [
            AppTextField(
              controller: _name,
              label: 'Nom du client',
              validator: Validators.name,
            ),
            AppTextField(
              controller: _phone,
              label: 'Téléphone',
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
          ],
        ),
        AppTextField(
          controller: _street,
          label: 'Adresse de livraison',
          prefixIcon: Icons.place_outlined,
          validator: (v) => Validators.required(v, field: "L'adresse"),
        ),
        AppFormRow(
          children: [
            AppTextField(
              controller: _postal,
              label: 'Code postal',
              keyboardType: TextInputType.number,
              validator: (v) => RegExp(r'^\d{5}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Code postal invalide',
            ),
            AppTextField(
              controller: _city,
              label: 'Ville',
              validator: (v) => Validators.required(v, field: 'La ville'),
            ),
          ],
        ),
        const AppFormSection(title: 'Articles'),
        FormField<int>(
          validator: (_) =>
              itemCount == 0 ? 'Ajoutez au moins un article' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (restaurant == null)
                Text(
                  'Choisissez d’abord le restaurant.',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                )
              else
                for (final p in products)
                  _ProductStepper(
                    product: p,
                    quantity: _quantities[p.id] ?? 0,
                    onChanged: (q) {
                      setState(() => _quantities[p.id] = q);
                      field.didChange(q);
                    },
                  ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    field.errorText!,
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppTextField(
          controller: _note,
          label: 'Note pour la cuisine (facultatif)',
          maxLines: 2,
        ),
        AppDropdownField<PaymentMethod>(
          label: 'Paiement',
          prefixIcon: Icons.payments_outlined,
          value: _payment,
          items: PaymentMethod.values,
          itemLabel: (m) => m.label,
          onChanged: (m) => setState(() => _payment = m ?? _payment),
        ),
        if (restaurant != null && itemCount > 0)
          _Totals(
            subtotal: subtotal,
            deliveryFee: restaurant.deliveryFee,
          ),
      ],
    );
  }
}

class _ProductStepper extends StatelessWidget {
  const _ProductStepper({
    required this.product,
    required this.quantity,
    required this.onChanged,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppNetworkImage(product.imageUrl, width: 40, height: 40),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                Text(
                  Formatters.price(product.price),
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: quantity == 0 ? null : () => onChanged(quantity - 1),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: context.text.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Ajouter',
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.subtotal, required this.deliveryFee});

  final double subtotal;
  final double deliveryFee;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, double value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? context.text.titleSmall : context.text.bodyMedium,
            ),
          ),
          Text(
            Formatters.price(value),
            style: bold ? context.text.titleMedium : context.text.bodyMedium,
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          line('Sous-total', subtotal),
          line('Livraison', deliveryFee),
          line('Frais de service', serviceFee),
          const Divider(),
          line('Total', subtotal + deliveryFee + serviceFee, bold: true),
        ],
      ),
    );
  }
}
