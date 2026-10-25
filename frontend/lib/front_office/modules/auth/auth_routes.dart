import 'package:go_router/go_router.dart';

import '../../../core/routing/page_transitions.dart';
import '../../router/front_routes.dart';
import 'presentation/pages/addresses_page.dart';
import 'presentation/pages/edit_profile_page.dart';
import 'presentation/pages/forgot_password_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/pages/otp_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/splash_page.dart';

/// Module 1 — parcours public : splash, onboarding, connexion, inscription,
/// vérification OTP et mot de passe oublié.
List<RouteBase> authPublicRoutes() => [
  transitionRoute(
    FrontRoutes.splash,
    (_, _) => const SplashPage(),
    type: PageTransitionType.fade,
  ),
  transitionRoute(
    FrontRoutes.onboarding,
    (_, _) => const OnboardingPage(),
    type: PageTransitionType.fade,
  ),
  transitionRoute(
    FrontRoutes.login,
    (_, _) => const LoginPage(),
    type: PageTransitionType.fade,
  ),
  transitionRoute(FrontRoutes.register, (_, _) => const RegisterPage()),
  transitionRoute(
    FrontRoutes.otp,
    (_, state) => OtpPage(
      phone: state.uri.queryParameters['phone'] ?? '',
      userId: state.uri.queryParameters['uid'],
    ),
  ),
  transitionRoute(
    FrontRoutes.forgotPassword,
    (_, _) => const ForgotPasswordPage(),
  ),
];

/// Module 1 — compte (plein écran, client et livreur) : modifier le profil,
/// adresses, paramètres. Le profil lui-même est un onglet (voir front_tabs).
List<RouteBase> accountRoutes() => [
  transitionRoute(FrontRoutes.editProfile, (_, _) => const EditProfilePage()),
  transitionRoute(FrontRoutes.addresses, (_, _) => const AddressesPage()),
  transitionRoute(FrontRoutes.settings, (_, _) => const SettingsPage()),
];
