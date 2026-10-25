import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Messages éphémères homogènes (succès, erreur, information).
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = Colors.white,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2800),
        // Largeur limitée sur grand écran (back office).
        width: MediaQuery.sizeOf(context).width > 600 ? 440 : null,
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    icon: Icons.check_circle_rounded,
    iconColor: AppColors.success,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void error(BuildContext context, Object error) => show(
    context,
    error.toString(),
    icon: Icons.error_rounded,
    iconColor: AppColors.error,
  );

  static void info(BuildContext context, String message) =>
      show(context, message);
}
