import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import '../utils/debouncer.dart';

/// Champ de recherche : icône, bouton effacer et saisie temporisée
/// ([onChanged] n'est appelé qu'après une courte pause de frappe).
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hint = 'Rechercher…',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.debounce = const Duration(milliseconds: 300),
    this.dense = false,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final Duration debounce;

  /// Hauteur réduite (barres d'outils, topbar).
  final bool dense;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final Debouncer _debouncer = Debouncer(delay: widget.debounce);

  @override
  void dispose() {
    _debouncer.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {}); // affiche / masque le bouton effacer
    _debouncer(() => widget.onChanged?.call(value.trim()));
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: _changed,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: widget.dense,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: widget.dense ? 12 : 16,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: context.palette.textSecondary,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}
