import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Affichage uniforme des messages éphémères (snackbars).
class AppSnackbar {
  AppSnackbar._();

  /// Messager des pages d'onglet (sous la barre de navigation, voir
  /// MainShell) : leurs messages s'affichent au-dessus de leur propre barre
  /// du bas (panier, validation…) et non sur la barre de navigation.
  static final GlobalKey<ScaffoldMessengerState> shellMessengerKey =
      GlobalKey<ScaffoldMessengerState>(debugLabel: 'shell-messenger');

  /// [keepAfterPop] : la page plein écran se ferme juste après ; le message
  /// s'affiche sur la page d'onglet qui réapparaît en dessous.
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = Colors.white,
    String? actionLabel,
    VoidCallback? onAction,
    bool keepAfterPop = false,
  }) {
    final messenger =
        (keepAfterPop ? shellMessengerKey.currentState : null) ??
        ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2600),
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
    bool keepAfterPop = false,
  }) => show(
    context,
    message,
    icon: Icons.check_circle_rounded,
    iconColor: AppColors.success,
    actionLabel: actionLabel,
    onAction: onAction,
    keepAfterPop: keepAfterPop,
  );

  static void error(BuildContext context, String message) => show(
    context,
    message,
    icon: Icons.error_rounded,
    iconColor: AppColors.error,
  );
}
