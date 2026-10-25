import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/address.dart';
import '../../providers/addresses_controller.dart';
import '../widgets/address_card.dart';
import '../widgets/address_form.dart';
import '../widgets/profile_widgets.dart';

/// Mes adresses (CRUD) : ajouter, modifier, définir par défaut, supprimer
/// (menu ou glisser vers la gauche).
class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  Future<bool> _confirmDelete(BuildContext context, Address address) =>
      ConfirmDeleteDialog.show(
        context,
        title: 'Supprimer cette adresse ?',
        message: '« ${address.label} » — ${address.fullAddress}',
      );

  Future<void> _delete(BuildContext context, WidgetRef ref, Address a) async {
    try {
      await ref.read(addressesProvider.notifier).remove(a);
      if (context.mounted) AppSnackbar.success(context, 'Adresse supprimée');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final controller = ref.read(addressesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AccountBackButton()),
        title: const Text('Mes adresses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAddressForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Ajouter'),
      ).animate().scaleXY(begin: 0.6, delay: 300.ms, curve: Curves.easeOutBack),
      body: AsyncValueView(
        value: addresses,
        onRetry: () => ref.invalidate(addressesProvider),
        loading: const ShimmerScope(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.pagePadding),
            child: Column(
              children: [
                SkeletonBox(height: 96),
                SizedBox(height: AppSizes.md),
                SkeletonBox(height: 96),
              ],
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.location_off_rounded,
                title: 'Aucune adresse',
                message: 'Ajoutez une adresse pour être livré plus vite.',
                actionLabel: 'Ajouter une adresse',
                onAction: () => openAddressForm(context),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.md,
                  AppSizes.pagePadding,
                  96,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
                itemBuilder: (context, i) {
                  final address = list[i];
                  return Dismissible(
                        key: ValueKey(address.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmDelete(context, address),
                        onDismissed: (_) => _delete(context, ref, address),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSizes.lg),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLg,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        child: AddressCard(
                          address: address,
                          onEdit: () =>
                              openAddressForm(context, address: address),
                          onSetDefault: () => controller.setDefault(address),
                          onDelete: () async {
                            if (await _confirmDelete(context, address) &&
                                context.mounted) {
                              await _delete(context, ref, address);
                            }
                          },
                        ),
                      )
                      .animate(delay: (60 * i).ms)
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.08, end: 0);
                },
              ),
      ),
    );
  }
}
