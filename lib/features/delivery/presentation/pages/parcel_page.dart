import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/animated_price.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../data/delivery_mock_data.dart';
import '../../models/tracking_step.dart';

/// Envoi de colis : itinéraire, taille, destinataire et options.
class ParcelPage extends StatefulWidget {
  const ParcelPage({super.key});

  @override
  State<ParcelPage> createState() => _ParcelPageState();
}

class _ParcelPageState extends State<ParcelPage> {
  static const _fragileFee = 1.5;
  static const _expressFee = 3.0;

  final _formKey = GlobalKey<FormState>();
  late final _pickup = TextEditingController(
    text: ProfileController.instance.selectedAddress.fullAddress,
  );
  final _dropoff = TextEditingController();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();

  ParcelSize _size = DeliveryMockData.parcelSizes[1];
  bool _fragile = false;
  bool _express = false;
  bool _submitted = false;
  bool _loading = false;

  double get _price =>
      _size.price + (_fragile ? _fragileFee : 0) + (_express ? _expressFee : 0);

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _recipient.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final order = OrdersController.instance.placeParcelOrder(
      sizeLabel: _size.label,
      pickup: _pickup.text.trim(),
      dropoff: _dropoff.text.trim(),
      price: _price,
      imageUrl: DeliveryMockData.parcelImage,
    );
    context.go(AppRoutes.confirmationOf(order.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Envoyer un colis'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.sm,
            AppSizes.pagePadding,
            AppSizes.xl,
          ),
          children: [
            const _HeroBanner(),
            const _Title('Itinéraire'),
            AppTextField(
              controller: _pickup,
              label: 'Adresse de retrait',
              prefixIcon: Icons.trip_origin_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.required(v, field: "L'adresse de retrait"),
            ),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _dropoff,
              label: 'Adresse de livraison',
              hint: 'Ex. : 8 rue de Rivoli, 75004 Paris',
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.required(v, field: "L'adresse de livraison"),
            ),
            const _Title('Taille du colis'),
            Row(
              children: [
                for (final (i, size)
                    in DeliveryMockData.parcelSizes.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _SizeCard(
                      size: size,
                      selected: size.id == _size.id,
                      onTap: () => setState(() => _size = size),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: AppDurations.fast,
              child: Text(
                _size.description,
                key: ValueKey(_size.id),
                style: context.text.bodySmall,
              ),
            ),
            const _Title('Destinataire'),
            AppTextField(
              controller: _recipient,
              label: 'Nom du destinataire',
              hint: 'Léa Dupont',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.name,
            ),
            const SizedBox(height: AppSizes.md),
            AppTextField(
              controller: _phone,
              label: 'Téléphone du destinataire',
              hint: '06 12 34 56 78',
              prefixIcon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const _Title('Options'),
            _OptionSwitch(
              icon: Icons.wine_bar_rounded,
              title: 'Colis fragile',
              subtitle:
                  'Manipulation avec précaution (+${Formatters.price(_fragileFee)})',
              value: _fragile,
              onChanged: (v) => setState(() => _fragile = v),
            ),
            const SizedBox(height: 10),
            _OptionSwitch(
              icon: Icons.bolt_rounded,
              title: 'Express',
              subtitle:
                  'Livraison prioritaire en 30 min (+${Formatters.price(_expressFee)})',
              value: _express,
              onChanged: (v) => setState(() => _express = v),
            ),
          ].animate(interval: 40.ms).fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
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
            label: 'Commander un coursier',
            isLoading: _loading,
            trailing: AnimatedPrice(_price),
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livré en moins de 60 min',
                  style: context.text.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Partout en ville, suivi en temps réel et assurance incluse.',
                  style: context.text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('📦', style: TextStyle(fontSize: 44))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: 1400.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.lg, bottom: 12),
      child: Text(text, style: context.text.titleMedium),
    );
  }
}

/// Carte de choix de taille de colis.
class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final ParcelSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      haptic: true,
      child: AnimatedContainer(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(
                  alpha: context.isDark ? 0.16 : 0.08,
                )
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : context.palette.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1,
              duration: AppDurations.medium,
              curve: Curves.easeOutBack,
              child: Icon(
                size.icon,
                color: selected
                    ? AppColors.primary
                    : context.palette.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(size.label, style: context.text.titleSmall),
            Text(
              Formatters.price(size.price),
              style: context.text.labelMedium?.copyWith(
                color: selected
                    ? AppColors.primary
                    : context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Option activable par un interrupteur.
class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
