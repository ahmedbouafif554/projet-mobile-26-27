import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/catalog/presentation/pages/favorites_page.dart';
import '../../features/catalog/presentation/pages/home_page.dart';
import '../../features/catalog/presentation/pages/product_page.dart';
import '../../features/catalog/presentation/pages/restaurant_page.dart';
import '../../features/catalog/presentation/pages/restaurants_page.dart';
import '../../features/catalog/presentation/pages/search_page.dart';
import '../../features/delivery/presentation/pages/parcel_page.dart';
import '../../features/delivery/presentation/pages/tracking_page.dart';
import '../../features/orders/presentation/pages/cart_page.dart';
import '../../features/orders/presentation/pages/checkout_page.dart';
import '../../features/orders/presentation/pages/order_confirmation_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/profile/presentation/pages/addresses_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/language_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../features/profile/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/payment_methods_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../widgets/animated_branch_container.dart';
import 'app_routes.dart';
import 'main_shell.dart';
import 'page_transitions.dart';

/// Configuration go_router de toute l'application.
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );

  /// Raccourci : route simple avec une transition donnée.
  static GoRoute _route(
    String path,
    Widget Function(GoRouterState state) builder, {
    PageTransitionType transition = PageTransitionType.slide,
  }) {
    return GoRoute(
      path: path,
      pageBuilder: (context, state) => buildTransitionPage(
        state: state,
        type: transition,
        child: builder(state),
      ),
    );
  }

  /// Onglet de la barre du bas (pas de transition : le conteneur gère le fondu).
  static StatefulShellBranch _tab(String path, Widget page) {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: path,
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: page),
        ),
      ],
    );
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      // --- Authentification ---
      _route(
        AppRoutes.splash,
        (_) => const SplashPage(),
        transition: PageTransitionType.fade,
      ),
      _route(
        AppRoutes.onboarding,
        (_) => const OnboardingPage(),
        transition: PageTransitionType.fade,
      ),
      _route(
        AppRoutes.login,
        (_) => const LoginPage(),
        transition: PageTransitionType.fade,
      ),
      _route(AppRoutes.register, (_) => const RegisterPage()),
      _route(AppRoutes.forgotPassword, (_) => const ForgotPasswordPage()),
      _route(
        AppRoutes.otp,
        (state) => OtpPage(phone: state.uri.queryParameters['phone'] ?? ''),
      ),

      // --- Onglets principaux (barre de navigation) ---
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AnimatedBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          _tab(AppRoutes.home, const HomePage()),
          _tab(AppRoutes.search, const SearchPage()),
          _tab(AppRoutes.orders, const OrdersPage()),
          _tab(AppRoutes.profile, const ProfilePage()),
        ],
      ),

      // --- Catalogue ---
      _route(
        AppRoutes.restaurants,
        (state) => RestaurantsPage(
          categoryId: state.uri.queryParameters['category'],
          filter: state.uri.queryParameters['filter'],
        ),
      ),
      _route(
        '${AppRoutes.restaurant}/:id',
        (state) => RestaurantPage(
          restaurantId: state.pathParameters['id']!,
          heroOrigin: state.uri.queryParameters['hero'] ?? 'list',
        ),
        transition: PageTransitionType.fade,
      ),
      _route(
        '${AppRoutes.product}/:id',
        (state) => ProductPage(
          productId: state.pathParameters['id']!,
          heroOrigin: state.uri.queryParameters['hero'] ?? 'menu',
        ),
        transition: PageTransitionType.fade,
      ),
      _route(AppRoutes.favorites, (_) => const FavoritesPage()),

      // --- Commandes & livraison ---
      _route(
        AppRoutes.cart,
        (_) => const CartPage(),
        transition: PageTransitionType.slideUp,
      ),
      _route(AppRoutes.checkout, (_) => const CheckoutPage()),
      _route(
        '${AppRoutes.orderConfirmation}/:id',
        (state) => OrderConfirmationPage(orderId: state.pathParameters['id']!),
        transition: PageTransitionType.scale,
      ),
      _route(
        '${AppRoutes.tracking}/:id',
        (state) => TrackingPage(orderId: state.pathParameters['id']!),
        transition: PageTransitionType.slideUp,
      ),
      _route(
        AppRoutes.parcel,
        (_) => const ParcelPage(),
        transition: PageTransitionType.slideUp,
      ),

      // --- Profil ---
      _route(AppRoutes.editProfile, (_) => const EditProfilePage()),
      _route(AppRoutes.addresses, (_) => const AddressesPage()),
      _route(AppRoutes.paymentMethods, (_) => const PaymentMethodsPage()),
      _route(
        AppRoutes.notificationSettings,
        (_) => const NotificationSettingsPage(),
      ),
      _route(AppRoutes.language, (_) => const LanguagePage()),
      _route(AppRoutes.notifications, (_) => const NotificationsPage()),

      // --- Administration ---
      _route(
        AppRoutes.admin,
        (_) => const AdminDashboardPage(),
        transition: PageTransitionType.scale,
      ),
    ],
  );
}
