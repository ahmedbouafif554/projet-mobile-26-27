import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selectable_chip.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../models/address.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_icons.dart';

/// Gestion des adresses de livraison.
class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddAddressSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Mes adresses'),
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final addresses = profile.addresses;
          return ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              Text(
                'Touchez une adresse pour la définir par défaut. Glissez vers la gauche pour la supprimer.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSizes.md),
              for (final (i, address) in addresses.indexed)
                Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: ValueKey('dismiss-${address.id}'),
                        direction: addresses.length > 1
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSizes.lg),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) {
                          profile.removeAddress(address.id);
                          AppSnackbar.show(
                            context,
                            'Adresse « ${address.label} » supprimée',
                            icon: Icons.delete_outline_rounded,
                          );
                        },
                        child: SelectableTile(
                          icon: addressIcon(address.type),
                          title: address.label,
                          subtitle: [
                            address.fullAddress,
                            if (address.instructions != null)
                              address.instructions!,
                          ].join('\n'),
                          selected: address.id == profile.selectedAddress.id,
                          onTap: () => profile.selectAddress(address.id),
                        ),
                      ),
                    )
                    .animate(
                      key: ValueKey('anim-${address.id}'),
                      delay: (60 * i).ms,
                    )
                    .fadeIn(duration: 350.ms)
                    .slideX(begin: 0.1, end: 0),
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
            label: 'Ajouter une adresse',
            icon: Icons.add_location_alt_rounded,
            onPressed: () => _openAddSheet(context),
          ),
        ),
      ),
    );
  }
}

/// Formulaire d'ajout d'adresse dans une feuille modale.
class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _instructions = TextEditingController();
  AddressType _type = AddressType.home;

  @override
  void dispose() {
    _label.dispose();
    _street.dispose();
    _city.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final label = _label.text.trim();
    ProfileController.instance.addAddress(
      Address(
        id: 'a${DateTime.now().millisecondsSinceEpoch}',
        label: label.isEmpty
            ? switch (_type) {
                AddressType.home => 'Maison',
                AddressType.work => 'Bureau',
                AddressType.other => 'Autre',
              }
            : label,
        street: _street.text.trim(),
        city: _city.text.trim(),
        type: _type,
        instructions: _instructions.text.trim().isEmpty
            ? null
            : _instructions.text.trim(),
      ),
    );
    Navigator.pop(context);
    AppSnackbar.success(context, 'Adresse ajoutée et sélectionnée');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Remonte le formulaire au-dessus du clavier.
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
              Text('Nouvelle adresse', style: context.text.titleLarge),
              const SizedBox(height: AppSizes.md),
              Wrap(
                spacing: 8,
                children: [
                  for (final (type, label) in const [
                    (AddressType.home, 'Maison'),
                    (AddressType.work, 'Bureau'),
                    (AddressType.other, 'Autre'),
                  ])
                    SelectableChip(
                      label: label,
                      icon: addressIcon(type),
                      selected: _type == type,
                      onTap: () => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              AppTextField(
                controller: _label,
                label: 'Nom (optionnel)',
                hint: 'Ex. : Chez mes parents',
                prefixIcon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _street,
                label: 'Adresse',
                hint: '10 rue de Rivoli',
                prefixIcon: Icons.signpost_outlined,
                validator: (v) => Validators.required(v, field: "L'adresse"),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _city,
                label: 'Code postal et ville',
                hint: '75004 Paris',
                prefixIcon: Icons.location_city_rounded,
                validator: (v) => Validators.required(v, field: 'La ville'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _instructions,
                label: 'Instructions (optionnel)',
                hint: 'Digicode, étage…',
                prefixIcon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: AppSizes.lg),
              PrimaryButton(label: 'Enregistrer', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
