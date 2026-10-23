import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../models/payment_method.dart';
import '../controllers/profile_controller.dart';
import '../widgets/payment_card_visual.dart';
import '../widgets/profile_icons.dart';

/// Moyens de paiement : cartes en carrousel, liste et ajout d'une carte.
class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Moyens de paiement'),
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final cards = profile.payments.where((p) => p.isCard).toList();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            children: [
              _CardsCarousel(
                cards: cards,
              ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.2, end: 0),
              const SizedBox(height: AppSizes.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moyen de paiement par défaut',
                      style: context.text.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final (i, method) in profile.payments.indexed)
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
                          )
                          .animate(delay: (50 * i).ms)
                          .fadeIn()
                          .slideY(begin: 0.2, end: 0),
                  ],
                ),
              ),
            ],
          );
        },
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
            label: 'Ajouter une carte',
            icon: Icons.add_card_rounded,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _AddCardSheet(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carrousel horizontal des cartes enregistrées.
class _CardsCarousel extends StatefulWidget {
  const _CardsCarousel({required this.cards});

  final List<PaymentMethod> cards;

  @override
  State<_CardsCarousel> createState() => _CardsCarouselState();
}

class _CardsCarouselState extends State<_CardsCarousel> {
  final _controller = PageController(viewportFraction: 0.86);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _controller,
        itemCount: cards.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: PaymentCardVisual(
            type: cards[i].type,
            number: '•••• •••• •••• ${cards[i].last4}',
            holder: cards[i].holder ?? '',
            expiry: cards[i].expiry ?? '',
          ),
        ),
      ),
    );
  }
}

/// Ajout d'une carte avec aperçu en direct.
class _AddCardSheet extends StatefulWidget {
  const _AddCardSheet();

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Met à jour l'aperçu de la carte à chaque frappe.
    for (final c in [_number, _holder, _expiry]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvc.dispose();
    super.dispose();
  }

  String get _digits => _number.text.replaceAll(' ', '');

  PaymentType get _type =>
      _digits.startsWith('5') ? PaymentType.mastercard : PaymentType.visa;

  /// « 4242 42•• •••• •••• » pendant la saisie.
  String get _previewNumber {
    final padded = _digits.padRight(16, '•');
    return [
      for (var i = 0; i < 16; i += 4) padded.substring(i, i + 4),
    ].join(' ');
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ProfileController.instance.addPayment(
      PaymentMethod(
        id: 'pm${DateTime.now().millisecondsSinceEpoch}',
        type: _type,
        label: _type == PaymentType.mastercard ? 'Mastercard' : 'Visa',
        last4: _digits.substring(_digits.length - 4),
        expiry: _expiry.text,
        holder: _holder.text.trim().toUpperCase(),
      ),
    );
    Navigator.pop(context);
    AppSnackbar.success(context, 'Carte ajoutée (simulation)');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nouvelle carte', style: context.text.titleLarge),
              const SizedBox(height: AppSizes.md),
              PaymentCardVisual(
                type: _type,
                number: _previewNumber,
                holder: _holder.text,
                expiry: _expiry.text,
              ),
              const SizedBox(height: AppSizes.lg),
              AppTextField(
                controller: _number,
                label: 'Numéro de carte',
                hint: '4242 4242 4242 4242',
                prefixIcon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                maxLength: 19,
                validator: (v) => (v ?? '').replaceAll(' ', '').length < 16
                    ? 'Numéro incomplet (16 chiffres)'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _holder,
                label: 'Titulaire',
                hint: 'Alex Martin',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.characters,
                validator: Validators.name,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _expiry,
                      label: 'Expiration',
                      hint: 'MM/AA',
                      prefixIcon: Icons.event_rounded,
                      keyboardType: TextInputType.datetime,
                      maxLength: 5,
                      validator: (v) =>
                          RegExp(r'^\d{2}/\d{2}$').hasMatch(v ?? '')
                          ? null
                          : 'Format MM/AA',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _cvc,
                      label: 'CVC',
                      hint: '123',
                      prefixIcon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      validator: (v) =>
                          (v ?? '').length == 3 ? null : '3 chiffres',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              PrimaryButton(
                label: 'Enregistrer la carte',
                icon: Icons.lock_rounded,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _save();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
