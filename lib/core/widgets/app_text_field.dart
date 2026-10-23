import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'shake_widget.dart';

/// Champ de texte animé :
/// - le libellé et l'icône prennent la couleur primaire au focus ;
/// - une ombre colorée apparaît autour du champ actif ;
/// - en cas d'erreur, le champ tremble et le message apparaît en douceur.
///
/// Compatible avec [Form] : la validation passe par [validator].
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  bool _focused = false;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_syncFormField);
  }

  void _onFocusChange() => setState(() => _focused = _focusNode.hasFocus);

  /// Garde la valeur du FormField synchronisée avec le contrôleur
  /// (y compris quand le texte est modifié par le code).
  void _syncFormField() {
    final field = _fieldKey.currentState;
    if (field != null && field.value != _controller.text) {
      field.didChange(_controller.text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_syncFormField);
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FormField<String>(
      key: _fieldKey,
      initialValue: _controller.text,
      validator: widget.validator,
      builder: (field) {
        final hasError = field.hasError;
        final accent = hasError
            ? AppColors.error
            : _focused
            ? AppColors.primary
            : palette.textSecondary;
        final errorBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm, left: 2),
                child: AnimatedDefaultTextStyle(
                  duration: AppDurations.fast,
                  style: context.text.labelLarge!.copyWith(
                    color: hasError
                        ? AppColors.error
                        : _focused
                        ? AppColors.primary
                        : context.colors.onSurface,
                  ),
                  child: Text(widget.label!),
                ),
              ),
            ShakeWidget(
              trigger: field.errorText,
              child: AnimatedContainer(
                duration: AppDurations.medium,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  obscureText: widget.isPassword && _obscured,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  maxLines: widget.isPassword ? 1 : widget.maxLines,
                  maxLength: widget.maxLength,
                  autofillHints: widget.autofillHints,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: context.text.bodyLarge,
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    counterText: '',
                    enabledBorder: hasError ? errorBorder : null,
                    focusedBorder: hasError ? errorBorder : null,
                    prefixIcon: widget.prefixIcon == null
                        ? null
                        : TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: accent),
                            duration: AppDurations.fast,
                            builder: (context, color, _) =>
                                Icon(widget.prefixIcon, color: color, size: 22),
                          ),
                    suffixIcon: widget.isPassword
                        ? IconButton(
                            onPressed: () =>
                                setState(() => _obscured = !_obscured),
                            icon: AnimatedSwitcher(
                              duration: AppDurations.fast,
                              transitionBuilder: (child, animation) =>
                                  RotationTransition(
                                    turns: Tween(
                                      begin: 0.75,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                              child: Icon(
                                _obscured
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                key: ValueKey(_obscured),
                                color: palette.textSecondary,
                              ),
                            ),
                          )
                        : widget.suffix,
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: AppDurations.fast,
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: hasError
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              field.errorText!,
                              style: context.text.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }
}
