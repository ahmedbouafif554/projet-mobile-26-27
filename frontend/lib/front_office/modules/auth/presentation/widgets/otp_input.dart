import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';

/// Saisie de code OTP : des cases animées pilotées par un champ invisible
/// (meilleure compatibilité clavier, copier-coller et effacement).
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.length = 4,
    this.hasError = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final int length;
  final bool hasError;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Taille des cases adaptée à la largeur disponible.
        final boxSize = math.min(
          64.0,
          (constraints.maxWidth - 12.0 * widget.length) / widget.length,
        );

        return Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (i) {
                final filled = i < text.length;
                final active =
                    _focusNode.hasFocus &&
                    (i == text.length ||
                        (i == widget.length - 1 &&
                            text.length == widget.length));
                final borderColor = widget.hasError
                    ? AppColors.error
                    : active
                    ? AppColors.primary
                    : filled
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : context.palette.border;

                return AnimatedContainer(
                  duration: AppDurations.fast,
                  width: boxSize,
                  height: boxSize * 1.15,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filled
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(
                      color: borderColor,
                      width: active ? 2 : 1.4,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : const [],
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: filled
                        ? Text(
                            text[i],
                            key: ValueKey('$i-${text[i]}'),
                            style: context.text.headlineSmall,
                          )
                        : active
                        ? const _BlinkingCursor()
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
            // Champ réel, invisible, qui reçoit la saisie.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  keyboardType: TextInputType.number,
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (value.length == widget.length) {
                      widget.onCompleted(value);
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlinkingCursor extends StatelessWidget {
  const _BlinkingCursor();

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 2,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeOut(duration: 500.ms, curve: Curves.easeInOut);
  }
}
