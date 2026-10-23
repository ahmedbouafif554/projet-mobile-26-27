import 'package:flutter/painting.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../models/onboarding_item.dart';

/// Données statiques du parcours d'authentification.
class AuthMockData {
  AuthMockData._();

  /// Identifiants pré-remplis pour tester rapidement.
  static const demoEmail = 'alex.martin@exemple.fr';
  static const demoPassword = 'superfaster';

  /// Code OTP accepté par l'écran de vérification.
  static const demoOtp = '1234';

  static final List<OnboardingItem> onboarding = [
    OnboardingItem(
      title: 'Vos restaurants préférés',
      description:
          'Des centaines de restaurants livrés chez vous en un temps record, de jour comme de nuit.',
      imageUrl: unsplash('1568901346375-23c9450c58cd', width: 600),
      accent: AppColors.primary,
      badges: const [('⭐', '4,9 / 5'), ('⚡', '25 min')],
    ),
    OnboardingItem(
      title: 'Vos courses en quelques clics',
      description:
          'Fruits, légumes et produits du quotidien livrés en moins de 30 minutes.',
      imageUrl: unsplash('1542838132-92c53300491e', width: 600),
      accent: AppColors.success,
      badges: const [('🥑', 'Produits frais'), ('🛵', 'Livraison offerte')],
    ),
    OnboardingItem(
      title: 'Colis express',
      description:
          'Envoyez et recevez vos colis partout en ville, avec un suivi en temps réel.',
      imageUrl: unsplash('1566576721346-d4a3b4eaeb55', width: 600),
      accent: const Color(0xFF6366F1),
      badges: const [('📦', 'Suivi live'), ('🔒', 'Assuré')],
    ),
  ];
}
