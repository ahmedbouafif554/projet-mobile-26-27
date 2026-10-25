import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Choix de l'utilisateur pour la sidebar : null = automatique (repliée sur
/// tablette, dépliée sur grand écran), sinon repliée (true) ou dépliée.
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool?>(
      SidebarCollapsedNotifier.new,
    );

class SidebarCollapsedNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  /// Inverse l'état affiché (calculé à partir de la largeur d'écran).
  void toggle({required bool currentlyCollapsed}) =>
      state = !currentlyCollapsed;
}
