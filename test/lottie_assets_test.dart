import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:superfaster/core/constants/app_assets.dart';

/// Vérifie que les animations Lottie embarquées sont lisibles.
void main() {
  for (final asset in [
    AppAssets.lottieWelcome,
    AppAssets.lottieSuccess,
    AppAssets.lottieEmptyCart,
  ]) {
    test('$asset se charge correctement', () async {
      final bytes = File(asset).readAsBytesSync();
      final composition = await LottieComposition.fromBytes(bytes);
      expect(composition.duration, greaterThan(Duration.zero));
      expect(composition.layers, isNotEmpty);
    });
  }
}
