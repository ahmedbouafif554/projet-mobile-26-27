import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_form_fields.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/widgets/status_chips.dart';
import '../../providers/courier_providers.dart';

/// Documents et véhicule du livreur : statut des justificatifs (validés dans
/// le back office), nouvel envoi, véhicule et zone.
class CourierDocumentsPage extends ConsumerStatefulWidget {
  const CourierDocumentsPage({super.key});

  @override
  ConsumerState<CourierDocumentsPage> createState() =>
      _CourierDocumentsPageState();
}

class _CourierDocumentsPageState extends ConsumerState<CourierDocumentsPage> {
  final _plate = TextEditingController();
  final _zone = TextEditingController();
  VehicleType? _vehicle;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _plate.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _save(Courier courier) async {
    setState(() => _saving = true);
    final plate = _plate.text.trim();
    try {
      await ref
          .read(myCourierProvider.notifier)
          .save(
            courier.copyWith(
              vehicle: _vehicle,
              plateNumber: _vehicle == VehicleType.bike || plate.isEmpty
                  ? null
                  : plate.toUpperCase(),
              zone: _zone.text.trim().isEmpty ? courier.zone : _zone.text.trim(),
            ),
          );
      if (mounted) AppSnackbar.success(context, 'Véhicule mis à jour');
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resubmit(DocumentType type) async {
    try {
      await ref.read(myCourierProvider.notifier).resubmit(type);
      if (mounted) {
        AppSnackbar.success(
          context,
          '${type.label} envoyé : vérification sous 24 h.',
        );
      }
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courier = ref.watch(myCourierProvider).value;
    if (courier != null && !_initialized) {
      _initialized = true;
      _vehicle = courier.vehicle;
      _plate.text = courier.plateNumber ?? '';
      _zone.text = courier.zone;
    }
    return Scaffold(
      body: SafeArea(
        child: courier == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.md,
                  AppSizes.pagePadding,
                  AppSizes.xl,
                ),
                children:
                    [
                          const PageTitle('Documents et véhicule'),
                          const SizedBox(height: AppSizes.md),
                          _StatusBanner(status: courier.documentStatus),
                          const SizedBox(height: AppSizes.lg),
                          Text('Justificatifs', style: context.text.titleLarge),
                          const SizedBox(height: AppSizes.sm),
                          for (final doc in courier.documents)
                            Container(
                              margin: const EdgeInsets.only(bottom: AppSizes.sm),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMd,
                                ),
                                boxShadow: context.palette.softShadow,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    switch (doc.type) {
                                      DocumentType.idCard => Icons.badge_rounded,
                                      DocumentType.license =>
                                        Icons.credit_card_rounded,
                                      DocumentType.insurance =>
                                        Icons.shield_outlined,
                                    },
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.type.label,
                                          style: context.text.titleSmall,
                                        ),
                                        Text(
                                          'Envoyé le ${Formatters.date(doc.uploadedAt)}',
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
                                  if (doc.status == DocumentStatus.rejected)
                                    TextButton(
                                      onPressed: () => _resubmit(doc.type),
                                      child: const Text('Renvoyer'),
                                    )
                                  else
                                    documentStatusChip(doc.status),
                                ],
                              ),
                            ),
                          const SizedBox(height: AppSizes.lg),
                          Text('Véhicule', style: context.text.titleLarge),
                          const SizedBox(height: AppSizes.md),
                          SegmentedButton<VehicleType>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: VehicleType.bike,
                                icon: Icon(Icons.pedal_bike_rounded),
                                label: Text('Vélo'),
                              ),
                              ButtonSegment(
                                value: VehicleType.scooter,
                                icon: Icon(Icons.two_wheeler_rounded),
                                label: Text('Scooter'),
                              ),
                              ButtonSegment(
                                value: VehicleType.car,
                                icon: Icon(Icons.directions_car_rounded),
                                label: Text('Voiture'),
                              ),
                            ],
                            selected: {_vehicle ?? courier.vehicle},
                            onSelectionChanged: (s) =>
                                setState(() => _vehicle = s.first),
                          ),
                          const SizedBox(height: AppSizes.md),
                          if (_vehicle != VehicleType.bike) ...[
                            AppTextField(
                              controller: _plate,
                              label: 'Immatriculation',
                              hint: 'AB-123-CD',
                              prefixIcon: Icons.pin_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: AppSizes.md),
                          ],
                          AppTextField(
                            controller: _zone,
                            label: 'Zone de livraison',
                            prefixIcon: Icons.map_outlined,
                          ),
                          const SizedBox(height: AppSizes.md),
                          const AppFormSection(
                            title: 'Bon à savoir',
                            subtitle:
                                'Un changement de véhicule peut nécessiter de nouveaux justificatifs.',
                          ),
                          const SizedBox(height: AppSizes.lg),
                          PrimaryButton(
                            label: 'Enregistrer',
                            isLoading: _saving,
                            onPressed: () => _save(courier),
                          ),
                        ]
                        .animate(interval: 40.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.05, end: 0),
              ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, message) = switch (status) {
      DocumentStatus.approved => (
        AppColors.success,
        Icons.verified_rounded,
        'Compte vérifié',
        'Vous pouvez recevoir des courses.',
      ),
      DocumentStatus.pending => (
        AppColors.warning,
        Icons.hourglass_top_rounded,
        'Vérification en cours',
        'Notre équipe vérifie vos documents (24 h maximum).',
      ),
      DocumentStatus.rejected => (
        AppColors.error,
        Icons.gpp_bad_rounded,
        'Document refusé',
        'Renvoyez le document refusé pour activer votre compte.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                Text(message, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
