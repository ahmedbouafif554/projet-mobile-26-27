import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'onboarding a-t-il déjà été vu pendant cette session ?
/// (À persister avec shared_preferences dans une vraie application.)
final onboardingSeenProvider = NotifierProvider<OnboardingSeenNotifier, bool>(
  OnboardingSeenNotifier.new,
);

class OnboardingSeenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markSeen() => state = true;
}
