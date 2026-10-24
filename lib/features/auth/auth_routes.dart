import '../../core/routes/module_routes.dart';
import '../../core/routes/page_transitions.dart';
import '../admin/presentation/pages/admin_dashboard_page.dart';
import '../profile/presentation/pages/addresses_page.dart';
import '../profile/presentation/pages/edit_profile_page.dart';
import '../profile/presentation/pages/language_page.dart';
import '../profile/presentation/pages/profile_page.dart';
import 'presentation/pages/forgot_password_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/pages/otp_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/splash_page.dart';

/// Routes du Module 1 — Authentification et utilisateurs (`/auth/...`).
///
/// Identifiant d'écran (modules_config.dart) → vraie page.
/// Les écrans prévus absents de cette table affichent un placeholder.
final ModuleRoutes authRoutes = ModuleRoutes(
  moduleNumber: 1,
  screens: {
    'splash': (_, _) => const SplashPage(),
    'onboarding': (_, _) => const OnboardingPage(),
    'register': (_, _) => const RegisterPage(),
    'login': (_, _) => const LoginPage(),
    'otp': (_, state) =>
        OtpPage(phone: state.uri.queryParameters['phone'] ?? ''),
    'forgot-password': (_, _) => const ForgotPasswordPage(),
    'profile': (_, _) => const ProfilePage(),
    'edit-profile': (_, _) => const EditProfilePage(),
    'addresses': (_, _) => const AddressesPage(),
    'language': (_, _) => const LanguagePage(),
    'admin-dashboard': (_, _) => const AdminDashboardPage(),
  },
  transitions: {
    'register': PageTransitionType.slide,
    'otp': PageTransitionType.slide,
    'forgot-password': PageTransitionType.slide,
    'admin-dashboard': PageTransitionType.scale,
  },
);
