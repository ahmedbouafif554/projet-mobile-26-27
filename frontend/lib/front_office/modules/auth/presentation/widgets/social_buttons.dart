import 'package:flutter/material.dart';

import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/pressable.dart';

/// Fournisseurs de connexion sociale (simulés).
enum SocialProvider { google, apple, facebook }

/// Rangée de boutons de connexion sociale.
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key, required this.onTap});

  final ValueChanged<SocialProvider> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            onTap: () => onTap(SocialProvider.google),
            // Lettre « G » stylisée (pas d'asset de marque nécessaire).
            child: Text(
              'G',
              style: context.text.titleLarge?.copyWith(
                color: const Color(0xFF4285F4),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _SocialButton(
            onTap: () => onTap(SocialProvider.apple),
            child: Icon(Icons.apple, size: 28, color: context.colors.onSurface),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _SocialButton(
            onTap: () => onTap(SocialProvider.facebook),
            child: const Icon(
              Icons.facebook_rounded,
              size: 28,
              color: Color(0xFF1877F2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        height: AppSizes.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: context.palette.border, width: 1.4),
        ),
        child: child,
      ),
    );
  }
}
