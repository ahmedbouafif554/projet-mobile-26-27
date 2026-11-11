import 'package:flutter/material.dart';

import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/pressable.dart';

/// Fournisseurs de connexion sociale. Seul Google est branché sur le
/// serveur ; Apple et Facebook restent masqués tant qu'ils ne le sont pas.
enum SocialProvider { google, apple, facebook }

/// Rangée de boutons de connexion sociale.
class SocialButtons extends StatelessWidget {
  const SocialButtons({
    super.key,
    required this.onTap,
    this.providers = const [SocialProvider.google],
  });

  final ValueChanged<SocialProvider> onTap;

  /// Fournisseurs affichés, dans l'ordre.
  final List<SocialProvider> providers;

  Widget _icon(BuildContext context, SocialProvider provider) =>
      switch (provider) {
        // Lettre « G » stylisée (pas d'asset de marque nécessaire).
        SocialProvider.google => Text(
          'G',
          style: context.text.titleLarge?.copyWith(
            color: const Color(0xFF4285F4),
            fontWeight: FontWeight.w800,
          ),
        ),
        SocialProvider.apple => Icon(
          Icons.apple,
          size: 28,
          color: context.colors.onSurface,
        ),
        SocialProvider.facebook => const Icon(
          Icons.facebook_rounded,
          size: 28,
          color: Color(0xFF1877F2),
        ),
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, provider) in providers.indexed) ...[
          if (i > 0) const SizedBox(width: AppSizes.md),
          Expanded(
            child: _SocialButton(
              onTap: () => onTap(provider),
              child: _icon(context, provider),
            ),
          ),
        ],
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
