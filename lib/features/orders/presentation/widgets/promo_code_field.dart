import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/shake_widget.dart';
import '../controllers/cart_controller.dart';

/// Champ de code promo : tremble si le code est invalide,
/// se transforme en carte verte quand il est appliqué.
class PromoCodeField extends StatefulWidget {
  const PromoCodeField({super.key});

  @override
  State<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends State<PromoCodeField> {
  final _controller = TextEditingController();
  int _errorCount = 0;
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    if (_controller.text.trim().isEmpty) return;
    final ok = CartController.instance.applyPromo(_controller.text);
    if (ok) {
      HapticFeedback.mediumImpact();
      FocusScope.of(context).unfocus();
      _controller.clear();
      setState(() => _hasError = false);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _errorCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartController.instance;

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final promo = cart.promo;
        return AnimatedSwitcher(
          duration: AppDurations.medium,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
          child: promo != null
              ? _AppliedPromo(
                  key: ValueKey(promo.code),
                  code: promo.code,
                  description: promo.description,
                  onRemove: cart.removePromo,
                )
              : _buildInput(context),
        );
      },
    );
  }

  Widget _buildInput(BuildContext context) {
    return Column(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShakeWidget(
          trigger: _errorCount == 0 ? null : _errorCount,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.only(left: 14, right: 6),
            height: 58,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: _hasError ? AppColors.error : context.palette.border,
                width: _hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      if (_hasError) setState(() => _hasError = false);
                    },
                    onSubmitted: (_) => _apply(),
                    style: context.text.titleSmall,
                    decoration: const InputDecoration(
                      hintText: 'Code promo',
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Pressable(
                  onTap: _apply,
                  scale: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Text(
                      'Appliquer',
                      style: context.text.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: AppDurations.fast,
          child: Text(
            _hasError
                ? 'Code invalide ou expiré'
                : 'Essayez BIENVENUE30, FAST5 ou LIVRAISON',
            key: ValueKey(_hasError),
            style: context.text.bodySmall?.copyWith(
              color: _hasError ? AppColors.error : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppliedPromo extends StatelessWidget {
  const _AppliedPromo({
    super.key,
    required this.code,
    required this.description,
    required this.onRemove,
  });

  final String code;
  final String description;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
          ).animate().scaleXY(
            begin: 0,
            end: 1,
            duration: 600.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: context.text.titleSmall?.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(description, style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Retirer le code',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
