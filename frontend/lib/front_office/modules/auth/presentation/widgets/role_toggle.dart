import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/models/user.dart';

/// Choix du rôle à la connexion ou à l'inscription.
/// Une pastille glisse sous l'option choisie.
/// L'inscription reste sur Client / Livreur ; la connexion peut ajouter Admin.
class RoleToggle extends StatelessWidget {
  const RoleToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.roles = const [UserRole.client, UserRole.courier],
    this.courierLabel = 'Livreur',
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;
  final List<UserRole> roles;
  final String courierLabel;

  String _label(UserRole role) => switch (role) {
    UserRole.client => 'Client',
    UserRole.courier => courierLabel,
    UserRole.admin => 'Admin',
    UserRole.restaurant => 'Restaurant',
  };

  IconData _icon(UserRole role) => switch (role) {
    UserRole.client => Icons.person_rounded,
    UserRole.courier => Icons.delivery_dining_rounded,
    UserRole.admin => Icons.admin_panel_settings_rounded,
    UserRole.restaurant => Icons.storefront_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = roles.isEmpty ? 1 : roles.length;
          final index = roles.indexOf(value);
          final selected = index < 0 ? 0 : index;
          final slot = constraints.maxWidth / count;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppDurations.medium,
                curve: Curves.easeOutBack,
                left: slot * selected,
                top: 0,
                bottom: 0,
                width: slot,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    boxShadow: context.palette.softShadow,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final role in roles)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: role == value,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                          onTap: () => onChanged(role),
                          child: _Option(
                            icon: _icon(role),
                            label: _label(role),
                            selected: role == value,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.palette.textSecondary;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selected ? 1.15 : 1,
            duration: AppDurations.fast,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              style: context.text.labelLarge!.copyWith(color: color),
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}
