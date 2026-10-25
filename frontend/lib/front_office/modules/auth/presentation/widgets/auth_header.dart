import 'package:flutter/material.dart';

import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_logo.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../router/front_routes.dart';

/// En-tête commun aux écrans d'authentification.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBack) ...[
              const AppBackButton(fallbackRoute: FrontRoutes.login),
              const Spacer(),
            ],
            const AppLogo(size: 52),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        Text(title, style: context.text.headlineMedium),
        const SizedBox(height: AppSizes.sm),
        Text(
          subtitle,
          style: context.text.bodyLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Séparateur « —— ou continuer avec ——».
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'ou continuer avec'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(label, style: context.text.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
