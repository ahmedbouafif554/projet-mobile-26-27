import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';

/// Titre de section dans un formulaire.
class AppFormSection extends StatelessWidget {
  const AppFormSection({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: context.text.labelMedium?.copyWith(
              color: context.palette.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// Deux champs (ou plus) côte à côte, empilés sur les écrans étroits.
class AppFormRow extends StatelessWidget {
  const AppFormRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const SizedBox(height: AppSizes.md),
                c,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(width: AppSizes.md),
              Expanded(child: c),
            ],
          ],
        );
      },
    );
  }
}

/// Liste déroulante avec libellé au-dessus (même rendu que AppTextField).
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.hint,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final IconData? prefixIcon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.sm, left: 2),
          child: Text(label, style: context.text.labelLarge),
        ),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          validator: validator,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          hint: hint == null ? null : Text(hint!),
          decoration: InputDecoration(
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(itemLabel(item))),
          ],
        ),
      ],
    );
  }
}

/// Interrupteur avec titre et description (disponible / rupture…).
class AppSwitchField extends StatelessWidget {
  const AppSwitchField({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: icon == null ? null : Icon(icon),
        title: Text(title, style: context.text.titleSmall),
        subtitle: subtitle == null ? null : Text(subtitle!),
      ),
    );
  }
}
