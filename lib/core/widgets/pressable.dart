import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Micro-interaction de base : le widget se « compresse » légèrement
/// quand on appuie dessus, puis revient à sa taille normale.
/// Utilisé par les cartes, boutons et icônes cliquables de l'application.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Échelle appliquée pendant l'appui (1 = aucun effet).
  final double scale;

  /// Ajoute une légère vibration au clic.
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      // Petit délai pour que l'effet reste visible même sur un clic rapide.
      onTapUp: _enabled
          ? (_) => Future.delayed(
              const Duration(milliseconds: 90),
              () => _setPressed(false),
            )
          : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
