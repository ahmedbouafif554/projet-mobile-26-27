import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:superfaster/back_office/modules/catalog/product_form.dart';
import 'package:superfaster/core/location/geocoding_service.dart';
import 'package:superfaster/core/network/api_exception.dart';
import 'package:superfaster/core/theme/app_theme.dart';
import 'package:superfaster/core/widgets/app_text_field.dart';
import 'package:superfaster/front_office/modules/catalog/providers/catalog_providers.dart';
import 'package:superfaster/shared/mock/mock_catalog.dart';
import 'package:superfaster/shared/models/models.dart';
import 'package:superfaster/shared/repositories/products/api_product_repository.dart';
import 'package:superfaster/shared/repositories/products/mock_product_repository.dart';
import 'package:superfaster/shared/repositories/repository_providers.dart';
import 'package:superfaster/shared/repositories/restaurants/api_restaurant_repository.dart';
import 'package:superfaster/shared/repositories/restaurants/mock_restaurant_repository.dart';

import '../test_helpers.dart';

/// Module Restaurants & Catalogue — API externes : « Près de moi »
/// (OpenStreetMap, côté serveur) et fiche produit par code-barres
/// (Open Food Facts, côté serveur). Aucun appel réseau réel.

/// Faux serveur HTTP : renvoie [body] et mémorise les requêtes reçues.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;

/// Position GPS simulée (ou erreur de localisation).
class _FakeGeocoding extends GeocodingService {
  _FakeGeocoding(this.result);

  final Object result;

  @override
  Future<LatLng> currentPosition() async {
    if (result is LatLng) return result as LatLng;
    throw result;
  }
}

/// Client rue Oberkampf (Paris 11e), près de Burger Factory (r1).
const _client = LatLng(48.864, 2.37);

/// Distance de référence (haversine), indépendante du code testé.
double _referenceKm(LatLng a, double lat, double lng) =>
    const Distance().as(LengthUnit.Meter, a, LatLng(lat, lng)) / 1000;

Map<String, dynamic> _restaurantJson(Map<String, dynamic> extra) => {
  'id': 'r',
  'name': 'Chez Test',
  'createdAt': '2026-01-01T00:00:00.000Z',
  ...extra,
};

/// Champ texte d'un AppTextField repéré par son libellé.
Finder _input(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(AppTextField)),
  matching: find.byType(EditableText),
);

String _text(WidgetTester tester, String label) =>
    tester.widget<EditableText>(_input(label)).controller.text;

NutriScore? _nutriScoreValue(WidgetTester tester) => tester
    .widget<DropdownButtonFormField<NutriScore?>>(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField<NutriScore?>),
    )
    .initialValue;

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<FilterChip>(find.widgetWithText(FilterChip, label)).selected;

void main() {
  setUpAll(setUpAppTestEnvironment);

  group('modèles', () {
    test('restaurant : localisation, délai estimé et code JSON du statut', () {
      final located = Restaurant.fromJson(
        _restaurantJson({
          'latitude': 48.86335,
          'longitude': 2.36939,
          'locationStatus': 'ok',
          'deliveryMinutes': 25,
          'estimatedMinutes': 31,
          'distanceKm': 2.7,
        }),
      );
      expect(located.hasLocation, isTrue);
      expect(located.deliveryTimeLabel, '26-36 min');
      expect(located.toJson()['locationStatus'], 'ok');

      final notFound = Restaurant.fromJson(
        _restaurantJson({
          'latitude': 48.8566,
          'longitude': 2.3522,
          'locationStatus': 'not_found',
        }),
      );
      expect(notFound.locationStatus, RestaurantLocationStatus.notFound);
      expect(notFound.hasLocation, isFalse);
      expect(notFound.toJson()['locationStatus'], 'not_found');

      // Ancienne réponse sans ces champs : à localiser, délai habituel.
      final legacy = Restaurant.fromJson(_restaurantJson({}));
      expect(legacy.locationStatus, RestaurantLocationStatus.pending);
      expect(legacy.hasLocation, isFalse);
      expect(legacy.estimatedMinutes, isNull);
      expect(legacy.deliveryTimeLabel, '25-35 min');
    });

    test('produit : code-barres, Nutri-Score et allergènes', () {
      final product = Product.fromJson({
        'id': 'p',
        'restaurantId': 'r',
        'name': 'Nutella',
        'barcode': '3017620422003',
        'nutriScore': 'e',
        'allergens': ['milk', 'nuts'],
      });
      expect(product.nutriScore, NutriScore.e);
      expect(product.allergens, ['milk', 'nuts']);
      expect(product.toJson()['nutriScore'], 'e');
      expect(Product.fromJson(product.toJson()).barcode, '3017620422003');

      final unknown = Product.fromJson({
        'id': 'p',
        'restaurantId': 'r',
        'name': 'X',
        'nutriScore': 'z',
      });
      expect(unknown.nutriScore, isNull);
      expect(unknown.allergens, isEmpty);
      expect(Allergens.labels, hasLength(14));
      expect(Allergens.label('nuts'), 'Fruits à coque');
    });

    test('code-barres GS1 : longueur et clé de contrôle', () {
      expect(isValidBarcode('3017620422003'), isTrue); // EAN-13
      expect(isValidBarcode('96385074'), isTrue); // EAN-8
      expect(isValidBarcode('3017 6204-22003'), isTrue);
      expect(isValidBarcode('3017620422004'), isFalse); // mauvaise clé
      expect(isValidBarcode('12345'), isFalse);
      expect(isValidBarcode('30176204220a3'), isFalse);
      expect(isValidBarcode(''), isFalse);
    });

    test('fiche Open Food Facts : calories pour 100 g ou par portion', () {
      final per100g = BarcodeProduct.fromJson({
        'barcode': '3017620422003',
        'name': 'Nutella',
        'calories': 539,
        'caloriesBasis': '100g',
        'allergens': ['milk'],
        'nutriScore': 'e',
      });
      expect(per100g.caloriesPer100g, isTrue);
      expect(per100g.nutriScore, NutriScore.e);
      final perServing = BarcodeProduct.fromJson({
        'barcode': '3017620422003',
        'calories': 80,
        'caloriesBasis': 'serving',
      });
      expect(perServing.caloriesPer100g, isFalse);
    });
  });

  group('dépôts démo', () {
    test('restaurants près du client : tri par distance et délai estimé', () async {
      final repository = MockRestaurantRepository(MockCatalog.restaurants);
      final near = await repository.getAllNear(_client);
      expect(near, hasLength(MockCatalog.restaurants.length));
      expect(near.first.id, 'r1');
      for (var i = 1; i < near.length; i++) {
        expect(near[i].distanceKm, greaterThanOrEqualTo(near[i - 1].distanceKm));
      }

      final burger = near.first;
      expect(burger.distanceKm, closeTo(_referenceKm(_client, 48.86335, 2.36939), 0.1));
      expect(burger.estimatedMinutes, burger.deliveryMinutes);

      // Plus de 2 km : 3 minutes par kilomètre en plus du délai annoncé.
      final far = near.firstWhere((r) => r.id == 'r10');
      expect(far.distanceKm, closeTo(_referenceKm(_client, 48.84465, 2.32779), 0.1));
      expect(
        far.estimatedMinutes,
        far.deliveryMinutes + ((far.distanceKm - 2) * 3).ceil(),
      );

      final one = await repository.getByIdNear('r10', _client);
      expect(one.distanceKm, far.distanceKm);
    });

    test('code-barres : fiche de démo, produit inconnu, code invalide', () async {
      final repository = MockProductRepository(MockCatalog.products);
      final found = await repository.lookupBarcode('3017620422003');
      expect(found.name, 'Nutella');
      expect(found.allergens, ['milk', 'nuts', 'soybeans']);

      await expectLater(
        repository.lookupBarcode('4006381333931'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 404)),
      );
      await expectLater(
        repository.lookupBarcode('3017620422004'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 422)),
      );
    });
  });

  group('dépôts API : requêtes envoyées au serveur', () {
    test('restaurants près de moi, fiche et relocalisation', () async {
      final restaurant = MockCatalog.restaurants.first.toJson();

      final list = _FakeAdapter([restaurant]);
      await ApiRestaurantRepository(_dio(list)).getAllNear(_client);
      expect(list.requests.single.path, '/restaurants');
      expect(list.requests.single.queryParameters, {
        'latitude': 48.864,
        'longitude': 2.37,
      });

      final one = _FakeAdapter(restaurant);
      await ApiRestaurantRepository(_dio(one)).getByIdNear('r1', _client);
      expect(one.requests.single.path, '/restaurants/r1');
      expect(one.requests.single.queryParameters['latitude'], 48.864);

      final relocate = _FakeAdapter(restaurant);
      await ApiRestaurantRepository(_dio(relocate)).relocate('r1');
      expect(relocate.requests.single.method, 'POST');
      expect(relocate.requests.single.path, '/restaurants/r1/geocode');
    });

    test('fiche par code-barres (espaces retirés)', () async {
      final adapter = _FakeAdapter({
        'barcode': '3017620422003',
        'name': 'Nutella',
        'description': 'Ferrero · 400 g',
        'calories': 539,
        'caloriesBasis': '100g',
        'allergens': ['milk', 'nuts', 'soybeans'],
        'nutriScore': 'e',
      });
      final found = await ApiProductRepository(
        _dio(adapter),
      ).lookupBarcode('3017 6204 22003');
      expect(adapter.requests.single.path, '/products/lookup/3017620422003');
      expect(found.description, 'Ferrero · 400 g');
      expect(found.nutriScore, NutriScore.e);
    });
  });

  group('« Près de moi »', () {
    ProviderContainer container(Object position) {
      final c = ProviderContainer(
        overrides: [
          geocodingServiceProvider.overrideWithValue(_FakeGeocoding(position)),
          restaurantRepositoryProvider.overrideWithValue(
            MockRestaurantRepository(MockCatalog.restaurants),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('la position du client donne distances et délais estimés', () async {
      final c = container(_client);
      final before = await c.read(restaurantsProvider.future);
      expect(before.every((r) => r.estimatedMinutes == null), isTrue);

      await c.read(userLocationProvider.notifier).locate();
      expect(c.read(userLocationProvider).position, _client);
      final after = await c.read(restaurantsProvider.future);
      expect(after.every((r) => r.estimatedMinutes != null), isTrue);
      // Les demandes d'inscription restent invisibles.
      expect(after.every((r) => r.isVisible), isTrue);

      final sorted = const RestaurantFilter(
        sort: RestaurantSort.nearest,
      ).apply(after);
      expect(sorted.first.id, 'r1');

      c.read(userLocationProvider.notifier).clear();
      expect(c.read(userLocationProvider).position, isNull);
    });

    test('localisation refusée : message lisible, rien ne change', () async {
      final c = container(const LocationException('Autorisez l’accès.'));
      await expectLater(
        c.read(userLocationProvider.notifier).locate(),
        throwsA(isA<LocationException>()),
      );
      final location = c.read(userLocationProvider);
      expect(location.position, isNull);
      expect(location.isLocating, isFalse);
    });

    test('tri « Plus proches » : restaurants non localisés à la fin', () {
      final unlocated = MockCatalog.restaurants.first.copyWith(
        id: 'sans-adresse',
        locationStatus: RestaurantLocationStatus.notFound,
        distanceKm: 0.1,
      );
      final located = MockCatalog.restaurants[1].copyWith(distanceKm: 3);
      final sorted = const RestaurantFilter(
        sort: RestaurantSort.nearest,
      ).apply([unlocated, located]);
      expect(sorted.map((r) => r.id), [located.id, 'sans-adresse']);
    });
  });

  group('formulaire produit (back office)', () {
    Future<void> pumpForm(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(ignoreOfflineImageErrors());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ProductForm()),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> search(WidgetTester tester, String code) async {
      await tester.enterText(_input('Code-barres EAN (facultatif)'), code);
      await tester.tap(find.byTooltip('Rechercher sur Open Food Facts'));
      await settle(tester);
    }

    testWidgets('un code-barres remplit la fiche depuis Open Food Facts', (
      tester,
    ) async {
      await pumpForm(tester);
      await search(tester, '3017620422003');

      expect(_text(tester, 'Nom'), 'Nutella');
      expect(_text(tester, 'Description'), 'Ferrero · 400 g');
      expect(_text(tester, 'Calories (facultatif)'), '539');
      expect(_text(tester, "URL de l'image"), contains('openfoodfacts.org'));
      expect(_nutriScoreValue(tester), NutriScore.e);
      expect(_chipSelected(tester, 'Lait'), isTrue);
      expect(_chipSelected(tester, 'Fruits à coque'), isTrue);
      expect(_chipSelected(tester, 'Soja'), isTrue);
      expect(_chipSelected(tester, 'Gluten'), isFalse);
      expect(
        find.textContaining('Fiche importée depuis Open Food Facts'),
        findsOneWidget,
      );
      expect(find.textContaining('calories pour 100 g'), findsOneWidget);
    });

    testWidgets('code invalide ou inconnu : message clair, fiche intacte', (
      tester,
    ) async {
      await pumpForm(tester);

      await search(tester, '3017620422004');
      expect(find.textContaining('Code-barres invalide'), findsWidgets);
      expect(_text(tester, 'Nom'), isEmpty);

      await search(tester, '4006381333931');
      expect(
        find.text('Aucun produit trouvé pour ce code-barres sur Open Food Facts.'),
        findsOneWidget,
      );
      expect(_text(tester, 'Nom'), isEmpty);
    });

    testWidgets('allergènes cochés à la main', (tester) async {
      await pumpForm(tester);
      expect(find.byType(FilterChip), findsNWidgets(14));
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Gluten'));
      await tester.tap(find.widgetWithText(FilterChip, 'Gluten'));
      await tester.pump();
      expect(_chipSelected(tester, 'Gluten'), isTrue);
      await tester.tap(find.widgetWithText(FilterChip, 'Gluten'));
      await tester.pump();
      expect(_chipSelected(tester, 'Gluten'), isFalse);
    });
  });
}
