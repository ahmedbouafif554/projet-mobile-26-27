/// Chemins des ressources locales (animations Lottie).
class AppAssets {
  AppAssets._();

  static const String lottieWelcome = 'assets/lottie/welcome.json';
  static const String lottieSuccess = 'assets/lottie/success.json';
  static const String lottieEmptyCart = 'assets/lottie/empty_cart.json';
}

/// Construit une URL d'image Unsplash optimisée (recadrée et compressée).
String unsplash(String photoId, {int width = 800}) =>
    'https://images.unsplash.com/photo-$photoId?auto=format&fit=crop&w=$width&q=80';
