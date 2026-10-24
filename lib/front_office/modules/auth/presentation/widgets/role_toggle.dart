import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../shared/models/user.dart';

/// Choix du rôle à la connexion / à l'inscription : Client ou Livreur.
/// Une pastille glisse sous l'option choisie.
class RoleToggle extends StatelessWidget {
  const RoleToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.courierLabel = 'Livreur',
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;
  final String courierLabel;

  static const _roles = [UserRole.client, UserRole.courier];

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
          final half = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppDurations.medium,
                curve: Curves.easeOutBack,
                left: value == UserRole.client ? 0 : half,
                top: 0,
                bottom: 0,
                width: half,
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
                  for (final role in _roles)
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
                            icon: role == UserRole.client
                                ? Icons.person_rounded
                                : Icons.delivery_dining_rounded,
                            label: role == UserRole.client
                                ? 'Client'
                                : courierLabel,
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
