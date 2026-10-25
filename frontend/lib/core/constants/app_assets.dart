/// Chemins des ressources locales (animations Lottie).
/// Les animations sont générées par `tool/generate_lottie.py` ; elles peuvent
/// être remplacées par des fichiers LottieFiles portant les mêmes noms.
class AppAssets {
  AppAssets._();

  static const String _lottie = 'assets/lottie';

  /// Accueil / onboarding.
  static const String lottieWelcome = '$_lottie/welcome.json';

  /// Validation réussie (commande confirmée, formulaire enregistré).
  static const String lottieSuccess = '$_lottie/success.json';

  /// État vide (panier vide, tableau sans résultat…).
  static const String lottieEmpty = '$_lottie/empty_cart.json';
}
