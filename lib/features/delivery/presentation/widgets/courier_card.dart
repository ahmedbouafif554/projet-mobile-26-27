import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../communication/communication_routes.dart';
import '../../models/courier.dart';

/// Carte du livreur : photo, note, véhicule, boutons message et appel.
class CourierCard extends StatelessWidget {
  const CourierCard({super.key, required this.courier});

  final Courier courier;

  Future<void> _call(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.phone_in_talk_rounded,
          color: AppColors.success,
          size: 36,
        ),
        title: Text('Appeler ${courier.name} ?'),
        content: const Text(
          'Votre numéro reste masqué pendant l\'appel (simulation).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Appeler'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppSnackbar.show(context, 'Appel en cours…', icon: Icons.phone_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          ClipOval(
            child: AppNetworkImage(courier.photoUrl, width: 52, height: 52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courier.name, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: context.palette.warning,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '${courier.rating.toStringAsFixed(1).replaceAll('.', ',')} • ${courier.deliveries} courses',
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${courier.vehicle} • ${courier.plate}',
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Envoyer un message',
            onTap: () => context.push(CommunicationRoutes.chat('conv-courier')),
          ),
          const SizedBox(width: 8),
          CircleIconButton(
            icon: Icons.phone_rounded,
            backgroundColor: AppColors.success,
            iconColor: Colors.white,
            tooltip: 'Appeler',
            onTap: () => _call(context),
          ),
        ],
      ),
    );
  }
}
