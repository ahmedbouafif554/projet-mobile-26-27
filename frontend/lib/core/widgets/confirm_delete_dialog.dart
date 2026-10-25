import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';

/// Demande de confirmation avant une action destructive.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Supprimer',
    this.icon = Icons.delete_outline_rounded,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;

  /// Renvoie `true` si l'utilisateur confirme.
  static Future<bool> show(
    BuildContext context, {
    String title = 'Supprimer cet élément ?',
    required String message,
    String confirmLabel = 'Supprimer',
    IconData icon = Icons.delete_outline_rounded,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmDeleteDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          icon: icon,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.error, size: 30),
              ).animate().shake(hz: 3, duration: 450.ms),
              const SizedBox(height: AppSizes.md),
              Text(
                title,
                style: context.text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm + 4),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
