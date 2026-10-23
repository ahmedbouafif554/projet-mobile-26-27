import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../orders/models/order.dart';
import '../../data/delivery_mock_data.dart';
import '../../models/tracking_step.dart';

/// État visuel d'une étape.
enum _StepState { done, active, pending }

/// Frise verticale des étapes de livraison. L'étape en cours pulse,
/// les traits se colorent au fur et à mesure.
class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = DeliveryMockData.steps;
    final current = steps.indexWhere((s) => s.status == status);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            state: status == OrderStatus.delivered || i < current
                ? _StepState.done
                : i == current
                ? _StepState.active
                : _StepState.pending,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.state,
    required this.isLast,
  });

  final TrackingStep step;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final pending = state == _StepState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _StepDot(icon: step.icon, state: state),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: AnimatedContainer(
                        duration: AppDurations.slow,
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: state == _StepState.done
                              ? AppColors.success
                              : context.palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSizes.lg,
                top: 6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppDurations.medium,
                    style: context.text.titleSmall!.copyWith(
                      color: pending ? context.palette.textSecondary : null,
                    ),
                    child: Text(step.title),
                  ),
                  const SizedBox(height: 2),
                  Text(step.subtitle, style: context.text.bodySmall),
                  if (state == _StepState.active)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child:
                          Text(
                                'En cours…',
                                style: context.text.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(begin: 0.4, end: 1, duration: 800.ms),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.icon, required this.state});

  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.primary,
      _StepState.pending => context.palette.border,
    };

    final dot = AnimatedContainer(
      duration: AppDurations.medium,
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: state == _StepState.pending ? context.colors.surface : color,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: AnimatedSwitcher(
        duration: AppDurations.medium,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          state == _StepState.done ? Icons.check_rounded : icon,
          key: ValueKey(state),
          size: 19,
          color: state == _StepState.pending
              ? context.palette.textSecondary
              : Colors.white,
        ),
      ),
    );

    if (state != _StepState.active) return dot;

    // Halo pulsant autour de l'étape active
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(begin: 1, end: 1.6, duration: 1200.ms)
            .fadeOut(duration: 1200.ms),
        dot,
      ],
    );
  }
}
