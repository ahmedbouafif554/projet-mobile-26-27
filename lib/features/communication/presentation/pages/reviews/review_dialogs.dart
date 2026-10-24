import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';

/// Confirmation avant suppression d'un avis.
Future<bool> confirmDeleteReview(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.error,
        size: 34,
      ),
      title: const Text('Supprimer cet avis ?'),
      content: const Text(
        'Il sera retiré définitivement de la page du restaurant.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: const Size(110, 44),
          ),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Choix du motif de signalement (null si annulé).
Future<String?> pickReportReason(BuildContext context) {
  const reasons = [
    'Contenu offensant ou haineux',
    'Faux avis / publicité',
    'Hors sujet',
    'Informations personnelles',
  ];
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              0,
              AppSizes.pagePadding,
              8,
            ),
            child: Text(
              'Pourquoi signaler cet avis ?',
              style: context.text.titleMedium,
            ),
          ),
          for (final reason in reasons)
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: AppColors.primary,
              ),
              title: Text(reason),
              onTap: () => Navigator.pop(sheetContext, reason),
            ),
        ],
      ),
    ),
  );
}
