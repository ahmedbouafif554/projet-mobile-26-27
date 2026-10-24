import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/status_chip.dart';
import '../../../../../shared/models/address.dart';

IconData addressIcon(AddressType type) => switch (type) {
  AddressType.home => Icons.home_rounded,
  AddressType.work => Icons.work_rounded,
  AddressType.other => Icons.place_rounded,
};

/// Carte d'une adresse : type, libellé, adresse complète et actions.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final selected = address.isDefault;
    return AnimatedContainer(
      duration: AppDurations.medium,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: AppCard(
        onTap: onEdit,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(addressIcon(address.type), color: AppColors.primary),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(address.label, style: context.text.titleMedium),
                      if (selected)
                        const StatusChip(
                          label: 'Par défaut',
                          tone: StatusTone.primary,
                          icon: Icons.check_rounded,
                          dense: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address.fullAddress, style: context.text.bodyMedium),
                  if (address.instructions != null &&
                      address.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address.instructions!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => switch (action) {
                'edit' => onEdit(),
                'default' => onSetDefault(),
                _ => onDelete(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                if (!selected)
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Définir par défaut'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Supprimer',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
