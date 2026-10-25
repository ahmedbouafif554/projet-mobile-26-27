import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import 'crud_repository.dart';

/// Base des dépôts mock : les données vivent en mémoire pendant la session
/// (créer, modifier et supprimer fonctionnent vraiment pendant la démo) et
/// chaque appel simule un délai réseau de 300 à 800 ms.
abstract class MockCrudRepository<T> implements CrudRepository<T> {
  MockCrudRepository(Iterable<T> seed, {required this.idPrefix})
    : _items = [...seed];

  final List<T> _items;

  /// Préfixe des identifiants générés (`u` → `u-1712…`).
  final String idPrefix;

  static final _random = Random();
  static int _sequence = 0;

  String idOf(T item);

  /// Copie de [item] avec l'identifiant [id] (utilisé à la création).
  T withId(T item, String id);

  /// Simule la latence du réseau.
  @protected
  Future<void> latency() {
    final min = AppConfig.mockLatencyMin.inMilliseconds;
    final max = AppConfig.mockLatencyMax.inMilliseconds;
    final ms = max <= min ? min : min + _random.nextInt(max - min);
    return Future.delayed(Duration(milliseconds: ms));
  }

  /// Instantané des données (sans délai), pour les sous-classes.
  @protected
  List<T> get items => List.unmodifiable(_items);

  @protected
  String newId() =>
      '$idPrefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  @protected
  ApiException notFound(String id) =>
      ApiException('Élément introuvable ($id).', statusCode: 404);

  int _indexOf(String id) => _items.indexWhere((e) => idOf(e) == id);

  @override
  Future<List<T>> getAll() async {
    await latency();
    return List.of(_items);
  }

  @override
  Future<T> getById(String id) async {
    await latency();
    final index = _indexOf(id);
    if (index < 0) throw notFound(id);
    return _items[index];
  }

  @override
  Future<T> create(T item) async {
    await latency();
    final created = idOf(item).isEmpty ? withId(item, newId()) : item;
    if (_indexOf(idOf(created)) >= 0) {
      throw ApiException('Cet élément existe déjà.', statusCode: 409);
    }
    _items.insert(0, created);
    return created;
  }

  @override
  Future<T> update(T item) async {
    await latency();
    final index = _indexOf(idOf(item));
    if (index < 0) throw notFound(idOf(item));
    _items[index] = item;
    return item;
  }

  @override
  Future<void> delete(String id) async {
    await latency();
    final index = _indexOf(id);
    if (index < 0) throw notFound(id);
    _items.removeAt(index);
  }

  /// Éléments filtrés (avec délai réseau).
  @protected
  Future<List<T>> where(bool Function(T item) test) async {
    await latency();
    return _items.where(test).toList();
  }

  /// Modifie un élément en mémoire (avec délai réseau) et le renvoie.
  @protected
  Future<T> mutate(String id, T Function(T item) change) async {
    await latency();
    final index = _indexOf(id);
    if (index < 0) throw notFound(id);
    return _items[index] = change(_items[index]);
  }

  /// Remplace toutes les données d'un coup (réordonnancement, sans délai).
  @protected
  void replaceAll(Iterable<T> items) => _items
    ..clear()
    ..addAll(items);
}
