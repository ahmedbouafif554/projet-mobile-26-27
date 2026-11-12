import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import 'order_widgets.dart';
import '../../domain/livreur_tip.dart';
import '../../providers/gift_tip_providers.dart';

/// Feuille modale présentant l'historique complet des pourboires reçus par un livreur.
class CourierTipHistorySheet extends ConsumerWidget {
  const CourierTipHistorySheet({super.key, required this.courierId});

  final String courierId;

  static void show(BuildContext context, String courierId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourierTipHistorySheet(courierId: courierId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(courierTipHistoryProvider(courierId));

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        16,
        AppSizes.pagePadding,
        AppSizes.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: Colors.amber,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mes Pourboires Livreur',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Historique de vos gratifications clients',
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Impossible de charger les pourboires : $err'),
              ),
              data: (data) {
                final totalEarned = ((data['totalEarned'] ?? 0) as num).toDouble();
                final count = (data['count'] ?? 0) as int;
                final rawTips = (data['tips'] as List?) ?? [];
                final tips = rawTips
                    .map((e) => LivreurTip.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();

                return Column(
                  children: [
                    // Carte récapitulative des gains
                    SurfaceCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total accumulé',
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.price(totalEarned),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 44,
                            width: 1,
                            color: context.palette.border,
                          ),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nombre',
                                style: context.text.bodySmall?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$count pourboire${count > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (tips.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.volunteer_activism_outlined,
                                size: 54,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun pourboire pour le moment.',
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: tips.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final tip = tips[index];
                            return SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '+${Formatters.price(tip.amount)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.green,
                                        ),
                                      ),
                                      if (tip.percentage != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${tip.percentage!.toInt()}%',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        Formatters.dateTime(tip.createdAt),
                                        style: ctx.text.bodySmall?.copyWith(
                                          color: ctx.palette.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tip.orderReference != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Commande #${tip.orderReference}',
                                      style: ctx.text.labelSmall?.copyWith(
                                        color: ctx.palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (tip.thankYouMessage != null &&
                                      tip.thankYouMessage!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: ctx.palette.surfaceMuted,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.format_quote_rounded,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              tip.thankYouMessage!,
                                              style: ctx.text.bodySmall?.copyWith(
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
