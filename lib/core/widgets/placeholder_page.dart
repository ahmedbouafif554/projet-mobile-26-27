import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../config/modules_config.dart';
import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';

/// Page temporaire d'un écran prévu : titre, module responsable,
/// route et fichier à modifier, bouton retour.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.module,
    required this.screen,
  });

  final AppModule module;
  final PlannedScreen screen;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(module.route);

  @override
  Widget build(BuildContext context) {
    final accent = module.accent;
    final roles = screen.roles.isEmpty
        ? 'Tous les rôles'
        : screen.roles.map((r) => r.label).join(', ');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => _back(context),
        ),
        title: Text(screen.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children:
                [
                      Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(screen.icon, size: 52, color: accent),
                          )
                          .animate()
                          .scaleXY(
                            begin: 0.5,
                            end: 1,
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          )
                          // Flottement continu
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(
                            begin: -4,
                            end: 4,
                            duration: 1600.ms,
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(height: 24),
                      Text(
                        screen.title,
                        style: context.text.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.construction_rounded,
                              size: 18,
                              color: accent,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              // Espace insécable : « Module N » reste sur une ligne.
                              child: Text(
                                'En cours de développement par le Module ${module.number}',
                                style: context.text.labelLarge?.copyWith(
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        module.name,
                        style: context.text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.link_rounded,
                              label: 'Route',
                              value: module.routeOf(screen.id),
                            ),
                            _InfoRow(
                              icon: Icons.description_outlined,
                              label: 'À remplacer dans',
                              value: module.routesFile,
                            ),
                            _InfoRow(
                              icon: screen.fullScreen
                                  ? Icons.open_in_full_rounded
                                  : Icons.tab_rounded,
                              label: 'Affichage',
                              value: screen.fullScreen
                                  ? 'Plein écran'
                                  : 'Dans l\'onglet ${module.label}',
                            ),
                            _InfoRow(
                              icon: Icons.group_outlined,
                              label: 'Rôles',
                              value: roles,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _back(context),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Retour'),
                      ),
                    ]
                    .animate(interval: 50.ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall),
                Text(value, style: context.text.labelLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
