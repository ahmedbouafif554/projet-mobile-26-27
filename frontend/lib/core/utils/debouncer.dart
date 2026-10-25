import 'dart:async';

import 'package:flutter/foundation.dart';

/// Retarde une action tant que l'utilisateur continue de taper
/// (recherche, filtres).
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
