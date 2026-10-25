import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/front_office/router/front_routes.dart';

import '../test_helpers.dart';
import 'front_test_utils.dart';

/// Test de fumée : chaque écran du front office s'affiche sans exception ni
/// débordement, pour chaque rôle, petit et grand téléphone, clair et sombre.
void main() {
  setUpAll(setUpAppTestEnvironment);

  const screens = <String?, List<String>>{
    // Non connecté
    null: [
      FrontRoutes.onboarding,
      FrontRoutes.login,
      FrontRoutes.register,
      '${FrontRoutes.otp}?phone=0611223344&uid=u-client-1',
      FrontRoutes.forgotPassword,
    ],
    'u-client-1': [
      FrontRoutes.explore,
      FrontRoutes.restaurants,
      '/explore/restaurant/r1',
      '/explore/restaurant/r1/reviews',
      FrontRoutes.search,
      FrontRoutes.cart,
      FrontRoutes.checkout,
      FrontRoutes.orders,
      '/orders/o-1',
      '/orders/o-1/track',
      '/orders/o-13/review',
      '/order-confirmed/o-1',
      FrontRoutes.profile,
      FrontRoutes.editProfile,
      FrontRoutes.addresses,
      FrontRoutes.settings,
      FrontRoutes.favorites,
      FrontRoutes.myReviews,
      FrontRoutes.notifications,
      FrontRoutes.notificationSettings,
      FrontRoutes.messages,
      '/account/messages/chat-1',
    ],
    'u-courier-1': [
      FrontRoutes.courierDashboard,
      FrontRoutes.courierDeliveries,
      '/courier/deliveries/d-7',
      FrontRoutes.courierEarnings,
      FrontRoutes.courierMessages,
      '/courier/messages/chat-2',
      FrontRoutes.courierProfile,
      FrontRoutes.editProfile,
      FrontRoutes.settings,
      FrontRoutes.documents,
      FrontRoutes.notifications,
    ],
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in const [Size(320, 640), Size(412, 915)]) {
      testWidgets('écrans (${mode.name}, ${size.width.toInt()} px)', (
        tester,
      ) async {
        final restore = ignoreOfflineImageErrors();
        for (final entry in screens.entries) {
          for (final location in entry.value) {
            final app = await pumpFront(
              tester,
              userId: entry.key,
              location: location,
              size: size,
              mode: mode,
            );
            await settle(tester, 1500);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Exception sur $location',
            );
            expect(
              app.path,
              Uri.parse(location).path,
              reason: 'Redirection inattendue depuis $location',
            );
            await unmountFront(tester);
          }
        }
        restore();
      });
    }
  }
}
