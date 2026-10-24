import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_logo.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../router/front_routes.dart';
import '../../data/onboarding_content.dart';
import '../../providers/onboarding_provider.dart';
import '../widgets/onboarding_slide.dart';

/// Onboarding en 3 slides, indicateur et bouton de progression animés.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _index = 0;

  bool get _isLast => _index == onboardingSlides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingSeenProvider.notifier).markSeen();
    context.go(FrontRoutes.login);
  }

  void _next() {
    if (_isLast) return _finish();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.sm,
                AppSizes.sm,
                0,
              ),
              child: Row(
                children: [
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AppLogo(size: 36, showName: true),
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: AppDurations.fast,
                    child: TextButton(
                      onPressed: _isLast ? null : _finish,
                      child: const Text('Passer'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingSlides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    OnboardingSlide(item: onboardingSlides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                0,
                AppSizes.pagePadding,
                AppSizes.lg,
              ),
              child: Row(
                children: [
                  _PageDots(count: onboardingSlides.length, index: _index),
                  const Spacer(),
                  _NextButton(
                    progress: (_index + 1) / onboardingSlides.length,
                    isLast: _isLast,
                    onTap: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicateur de pages : le point actif s'allonge.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : context.palette.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Bouton rond avec anneau de progression, qui devient « Commencer »
/// sur la dernière slide.
class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.progress,
    required this.isLast,
    required this.onTap,
  });

  final double progress;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: isLast ? 0 : 1,
              duration: AppDurations.fast,
              child: SizedBox(
                width: 72,
                height: 72,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: AppDurations.slow,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3,
                    color: AppColors.primary,
                    backgroundColor: context.palette.border,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: AppDurations.medium,
              curve: Curves.easeOutCubic,
              width: isLast ? 170 : 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: isLast
                      ? Center(
                          key: const ValueKey('start'),
                          child: Text(
                            'Commencer',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: context.text.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          key: ValueKey('next'),
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
