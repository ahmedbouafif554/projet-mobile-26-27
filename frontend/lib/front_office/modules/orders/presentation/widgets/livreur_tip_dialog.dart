import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/models/order.dart';
import '../../domain/livreur_tip.dart';
import '../../providers/gift_tip_providers.dart';

/// Modal interactif permettant de laisser un pourboire au livreur (avant ou après livraison).
class LivreurTipBottomSheet extends ConsumerStatefulWidget {
  const LivreurTipBottomSheet({
    super.key,
    required this.order,
    this.courierName,
  });

  final Order order;
  final String? courierName;

  static Future<LivreurTip?> show(
    BuildContext context, {
    required Order order,
    String? courierName,
  }) {
    return showModalBottomSheet<LivreurTip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LivreurTipBottomSheet(
        order: order,
        courierName: courierName,
      ),
    );
  }

  @override
  ConsumerState<LivreurTipBottomSheet> createState() =>
      _LivreurTipBottomSheetState();
}

class _LivreurTipBottomSheetState extends ConsumerState<LivreurTipBottomSheet> {
  double? _selectedPercentage = 10.0;
  double _customAmount = 2.0;
  bool _isCustom = false;
  final _customController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _recalculateFromPercentage(10.0);
  }

  @override
  void dispose() {
    _customController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _recalculateFromPercentage(double pct) {
    setState(() {
      _selectedPercentage = pct;
      _isCustom = false;
      // Calculate amount based on order subtotal or total
      final total = widget.order.total;
      _customAmount = ((total * (pct / 100)) * 2).round() / 2; // round to nearest 0.50
      if (_customAmount < 1.0) _customAmount = 1.0;
      _customController.text = _customAmount.toStringAsFixed(2);
    });
  }

  double get _finalAmount {
    if (_isCustom) {
      final parsed = double.tryParse(_customController.text.replaceAll(',', '.'));
      return parsed ?? 2.0;
    }
    return _customAmount;
  }

  Future<void> _submitTip() async {
    final amount = _finalAmount;
    if (amount <= 0) {
      AppSnackbar.error(context, 'Le montant doit être supérieur à 0 €');
      return;
    }

    setState(() => _submitting = true);
    try {
      final tip = await ref.read(tipActionProvider).sendTip(
            orderId: widget.order.id,
            amount: amount,
            percentage: _isCustom ? null : _selectedPercentage,
            thankYouMessage: _messageController.text.trim(),
            paymentMethod: 'card',
          );

      if (mounted) {
        Navigator.pop(context, tip);
        AppSnackbar.success(
          context,
          'Merci ! Votre pourboire de ${Formatters.price(amount)} a été envoyé au livreur 💛',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Erreur lors de l’envoi du pourboire: $e');
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.courierName ?? 'Votre livreur';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        16,
        AppSizes.pagePadding,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de drag
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
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pourboire pour $name',
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '100% de votre pourboire lui est directement reversé.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Choix des pourcentages prédéfinis
            Text(
              'Choisir un montant',
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final pct in LivreurTip.predefinedPercentages) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => _recalculateFromPercentage(pct),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isCustom && _selectedPercentage == pct
                                ? AppColors.primary
                                : context.palette.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_isCustom && _selectedPercentage == pct
                                  ? AppColors.primary
                                  : context.palette.border,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${pct.toInt()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: !_isCustom && _selectedPercentage == pct
                                      ? Colors.white
                                      : context.colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${((widget.order.total * (pct / 100))).toStringAsFixed(1)}€',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: !_isCustom && _selectedPercentage == pct
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : context.palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // Option montant libre
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() {
                        _isCustom = true;
                        _selectedPercentage = null;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isCustom
                              ? AppColors.primary
                              : context.palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isCustom
                                ? AppColors.primary
                                : context.palette.border,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Autre',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _isCustom
                                    ? Colors.white
                                    : context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Libre',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isCustom
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : context.palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isCustom) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _customController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Montant personnalisé (€)',
                  prefixIcon: Icon(Icons.euro_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Message de remerciement personnalisé
            Text(
              'Message de remerciement (optionnel)',
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // Chips de messages rapides
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final msg in LivreurTip.quickMessages)
                  ActionChip(
                    label: Text(msg, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _messageController.text = msg,
                    backgroundColor: context.palette.surfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: context.palette.border),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Écrire un mot gentil pour votre livreur…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // Bouton de validation
            PrimaryButton(
              label: _submitting
                  ? 'Envoi en cours…'
                  : 'Envoyer ${Formatters.price(_finalAmount)} au livreur 💛',
              icon: Icons.favorite_rounded,
              onPressed: _submitting ? null : _submitTip,
            ),
          ],
        ),
      ),
    );
  }
}
