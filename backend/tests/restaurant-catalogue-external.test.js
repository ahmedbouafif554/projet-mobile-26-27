'use strict';

/**
 * Module Restaurants & Catalogue — API externes :
 *  - géolocalisation des adresses (OpenStreetMap / Nominatim) et « près de moi » ;
 *  - fiche produit par code-barres (Open Food Facts).
 * Les deux services sont simulés : aucun appel réseau réel pendant les tests.
 */

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const restaurantCatalogue = require('../src/restaurant_catalogue');
const { as, ADMIN } = require('./helpers');

const OWNER = as('u-resto-1');
const CLIENT = as('u-client-1');

// Coordonnées réelles renvoyées par Nominatim pour ces adresses.
const OBERKAMPF = '18 rue Oberkampf, Paris 11e';
const MONTPARNASSE = '15 rue du Montparnasse, Paris 6e';
const MARTYRS = '5 rue des Martyrs, Paris 9e';
const PLACES = {
  [OBERKAMPF.toLowerCase()]: { lat: 48.86335, lon: 2.36939 },
  [MONTPARNASSE.toLowerCase()]: { lat: 48.84465, lon: 2.32779 },
  [MARTYRS.toLowerCase()]: { lat: 48.87726, lon: 2.33927 },
};

const NUTELLA = '3017620422003';
const PRODUCTS = {
  [NUTELLA]: {
    product_name_fr: 'Nutella',
    product_name: 'Nutella',
    brands: 'Ferrero, Nutella',
    quantity: '400 g e',
    image_front_url: 'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.jpg',
    nutriscore_grade: 'e',
    allergens_tags: ['en:milk', 'en:nuts', 'en:soybeans', 'en:inconnu'],
    nutriments: { 'energy-kcal_100g': 539 },
  },
};

const ENV_KEYS = ['GEOCODING_ENABLED', 'GEOCODING_MIN_INTERVAL_MS'];
const savedEnv = {};
let fetchMock;

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Réponses simulées de Nominatim et d'Open Food Facts. */
function fakeApis(url) {
  const { hostname, pathname, searchParams } = new URL(url);
  if (hostname === 'nominatim.openstreetmap.org' && pathname === '/search') {
    const place = PLACES[searchParams.get('q').toLowerCase()];
    return json(200, place ? [{ lat: String(place.lat), lon: String(place.lon), display_name: 'Paris' }] : []);
  }
  if (hostname === 'world.openfoodfacts.org') {
    const code = pathname.match(/^\/api\/v2\/product\/(\d+)\.json$/)?.[1];
    return PRODUCTS[code]
      ? json(200, { status: 1, product: PRODUCTS[code] })
      : json(404, { status: 0, status_verbose: 'product not found' });
  }
  throw new Error(`Appel réseau inattendu : ${url}`);
}

function callsTo(hostname) {
  return fetchMock.mock.calls.filter(([url]) => new URL(String(url)).hostname === hostname);
}

/** Distance de référence (haversine), calculée indépendamment du code testé. */
function referenceKm(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const h =
    Math.sin(rad(b.lat - a.lat) / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(rad(b.lon - a.lon) / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(h));
}

function restaurantBody(extra = {}) {
  return {
    id: '',
    name: 'Chez Test',
    description: 'Cuisine maison',
    cuisine: 'Burgers',
    categoryIds: [],
    imageUrl: '',
    address: OBERKAMPF,
    phone: '0612345678',
    menuSections: ['Burgers'],
    ...extra,
  };
}

async function createRestaurant(extra = {}, headers = ADMIN) {
  const res = await request(app).post('/api/restaurants').set(headers).send(restaurantBody(extra));
  expect(res.status).toBe(201);
  return res.body;
}

beforeAll(async () => {
  for (const key of ENV_KEYS) savedEnv[key] = process.env[key];
  await init();
}, 30000);

beforeEach(async () => {
  process.env.GEOCODING_ENABLED = 'true';
  process.env.GEOCODING_MIN_INTERVAL_MS = '0';
  await reset();
  await restaurantCatalogue.init();
  await query('DELETE FROM geocode_cache');
  await query('DELETE FROM barcode_lookups');
  fetchMock = jest.spyOn(global, 'fetch').mockImplementation(async (url) => fakeApis(String(url)));
});

afterEach(() => {
  fetchMock.mockRestore();
});

afterAll(async () => {
  for (const key of ENV_KEYS) {
    if (savedEnv[key] === undefined) delete process.env[key];
    else process.env[key] = savedEnv[key];
  }
  await close();
});

// ── Géolocalisation (OpenStreetMap) ─────────────────────────────────────────

describe('géolocalisation des restaurants (OpenStreetMap)', () => {
  test('création : coordonnées trouvées, requête conforme aux règles de Nominatim', async () => {
    const restaurant = await createRestaurant();
    expect(restaurant).toMatchObject({
      latitude: 48.86335,
      longitude: 2.36939,
      locationStatus: 'ok',
      hasLocation: true,
      estimatedMinutes: null,
    });

    const [[url, options]] = callsTo('nominatim.openstreetmap.org');
    const params = new URL(url).searchParams;
    expect(params.get('q')).toBe(OBERKAMPF);
    expect(params.get('format')).toBe('jsonv2');
    expect(params.get('limit')).toBe('1');
    expect(params.get('countrycodes')).toBe('fr');
    expect(options.headers['User-Agent']).toMatch(/^SuperFaster\/1\.0 \(.+\)$/);
  });

  test('cache : une même adresse n’est demandée qu’une fois', async () => {
    await createRestaurant();
    const second = await createRestaurant({ address: `  ${OBERKAMPF.toUpperCase()}  ` });
    expect(second).toMatchObject({ latitude: 48.86335, locationStatus: 'ok' });
    expect(callsTo('nominatim.openstreetmap.org')).toHaveLength(1);
  });

  test('adresse introuvable : restaurant enregistré mais sans localisation', async () => {
    const restaurant = await createRestaurant({ address: '1 rue Imaginaire, Nullepart' });
    expect(restaurant).toMatchObject({ locationStatus: 'not_found', hasLocation: false });
  });

  test('service indisponible : restaurant enregistré quand même, puis relocalisé', async () => {
    fetchMock.mockImplementationOnce(async () => {
      throw new TypeError('fetch failed');
    });
    const restaurant = await createRestaurant();
    expect(restaurant).toMatchObject({ locationStatus: 'error', hasLocation: false });

    fetchMock.mockImplementationOnce(async () => json(503, {}));
    const stillDown = await request(app).post(`/api/restaurants/${restaurant.id}/geocode`).set(ADMIN);
    expect(stillDown.status).toBe(502);

    // Rien n'a été mis en cache : le service est redemandé et répond.
    const retried = await request(app).post(`/api/restaurants/${restaurant.id}/geocode`).set(ADMIN);
    expect(retried.status).toBe(200);
    expect(retried.body).toMatchObject({ locationStatus: 'ok', latitude: 48.86335 });
    expect(callsTo('nominatim.openstreetmap.org')).toHaveLength(3);
  });

  test('modification : nouvelle adresse relocalisée, sinon aucun appel ; coordonnées manuelles', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const put = (body) => request(app).put(`/api/restaurants/${restaurant.id}`).set(OWNER).send(body);

    // Aller-retour du formulaire : même adresse, mêmes coordonnées → pas d'appel.
    const same = await put({ ...restaurant, promo: '-10 %' });
    expect(same.body).toMatchObject({ promo: '-10 %', locationStatus: 'ok', latitude: 48.86335 });
    expect(callsTo('nominatim.openstreetmap.org')).toHaveLength(1);

    const moved = await put({ ...same.body, address: MARTYRS });
    expect(moved.body).toMatchObject({ address: MARTYRS, latitude: 48.87726, longitude: 2.33927 });
    expect(callsTo('nominatim.openstreetmap.org')).toHaveLength(2);

    const manual = await put({ ...moved.body, latitude: 48.85, longitude: 2.35 });
    expect(manual.body).toMatchObject({ latitude: 48.85, longitude: 2.35, locationStatus: 'manual' });
    expect(callsTo('nominatim.openstreetmap.org')).toHaveLength(2);

    // Coordonnées envoyées à null : les coordonnées connues sont gardées.
    const nulls = await put({ ...manual.body, latitude: null, longitude: null });
    expect(nulls.body).toMatchObject({ latitude: 48.85, longitude: 2.35, locationStatus: 'manual' });

    const half = await request(app).post('/api/restaurants').set(ADMIN).send(restaurantBody({ latitude: 48.85 }));
    expect(half.status).toBe(422);
  });

  test('près de moi : distance, délai estimé, tri et rayon', async () => {
    const near = await createRestaurant({ name: 'Proche', address: OBERKAMPF });
    const far = await createRestaurant({ name: 'Loin', address: MONTPARNASSE, deliveryMinutes: 25 });
    const unknown = await createRestaurant({ name: 'Inconnu', address: '1 rue Imaginaire, Nullepart' });
    const client = { lat: 48.864, lon: 2.37 };

    const res = await request(app)
      .get('/api/restaurants')
      .query({ latitude: client.lat, longitude: client.lon });
    expect(res.status).toBe(200);
    const ids = res.body.map((r) => r.id);
    expect(ids.indexOf(near.id)).toBeLessThan(ids.indexOf(far.id));
    // Sans coordonnées fiables (adresse introuvable, démo jamais localisée) : à la fin.
    expect(ids.indexOf(far.id)).toBeLessThan(ids.indexOf(unknown.id));
    expect(ids.indexOf(far.id)).toBeLessThan(ids.indexOf('rest_demo'));

    const byId = Object.fromEntries(res.body.map((r) => [r.id, r]));
    const nearKm = referenceKm(client, PLACES[OBERKAMPF.toLowerCase()]);
    const farKm = referenceKm(client, PLACES[MONTPARNASSE.toLowerCase()]);
    expect(byId[near.id].distanceKm).toBeCloseTo(nearKm, 1);
    expect(byId[far.id].distanceKm).toBeCloseTo(farKm, 1);
    // Délai annoncé (2 premiers km compris) + 3 min par km au-delà.
    expect(byId[near.id].estimatedMinutes).toBe(30);
    expect(byId[far.id].estimatedMinutes).toBe(25 + Math.ceil((byId[far.id].distanceKm - 2) * 3));
    expect(byId[unknown.id].estimatedMinutes).toBeNull();

    const within = await request(app)
      .get('/api/restaurants')
      .query({ latitude: client.lat, longitude: client.lon, radiusKm: 2 });
    expect(within.body.map((r) => r.id)).toEqual([near.id]);

    const one = await request(app)
      .get(`/api/restaurants/${far.id}`)
      .query({ latitude: client.lat, longitude: client.lon });
    expect(one.body.distanceKm).toBeCloseTo(farKm, 1);
  });

  test('près de moi : paramètres de position validés', async () => {
    const get = (params) => request(app).get('/api/restaurants').query(params);
    expect((await get({ latitude: 'abc', longitude: 2.35 })).status).toBe(422);
    expect((await get({ latitude: 48.85 })).status).toBe(422);
    expect((await get({ latitude: 91, longitude: 2.35 })).status).toBe(422);
    expect((await get({ radiusKm: 5 })).status).toBe(422);
    expect((await get({ latitude: 48.85, longitude: 2.35, radiusKm: 100 })).status).toBe(422);
  });

  test('relocalisation : admin ou restaurateur ; désactivée → 503', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const relocate = (headers) => request(app).post(`/api/restaurants/${restaurant.id}/geocode`).set(headers);

    expect((await relocate(OWNER)).status).toBe(200);
    expect((await relocate(CLIENT)).status).toBe(403);
    expect((await request(app).post(`/api/restaurants/${restaurant.id}/geocode`)).status).toBe(401);

    process.env.GEOCODING_ENABLED = 'false';
    expect((await relocate(ADMIN)).status).toBe(503);
  });

  test('géolocalisation désactivée : aucun appel réseau, restaurant « à localiser »', async () => {
    process.env.GEOCODING_ENABLED = 'false';
    const restaurant = await createRestaurant();
    expect(restaurant).toMatchObject({ locationStatus: 'pending', hasLocation: false });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test('localisation en lot des restaurants pas encore localisés (npm run geocode:catalogue)', async () => {
    process.env.GEOCODING_ENABLED = 'false';
    const pending = await createRestaurant({ address: MONTPARNASSE });
    process.env.GEOCODING_ENABLED = 'true';

    // Démo (« 10 rue Démo », introuvable) + le restaurant créé hors géolocalisation.
    const counts = await restaurantCatalogue.restaurantService.locatePending();
    expect(counts).toEqual({ ok: 1, not_found: 1, error: 0 });
    const located = await request(app).get(`/api/restaurants/${pending.id}`);
    expect(located.body).toMatchObject({ locationStatus: 'ok', latitude: 48.84465 });

    // Relancer ne redemande rien : plus aucun restaurant à localiser.
    expect(await restaurantCatalogue.restaurantService.locatePending()).toEqual({
      ok: 0,
      not_found: 0,
      error: 0,
    });
  });
});

// ── Code-barres (Open Food Facts) ───────────────────────────────────────────

describe('fiche produit par code-barres (Open Food Facts)', () => {
  test('restaurateur : fiche pré-remplie (nom, marque, photo, calories, allergènes, Nutri-Score)', async () => {
    const res = await request(app).get(`/api/products/lookup/${NUTELLA}`).set(OWNER);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      barcode: NUTELLA,
      name: 'Nutella',
      description: 'Ferrero · 400 g',
      imageUrl: PRODUCTS[NUTELLA].image_front_url,
      calories: 539,
      caloriesBasis: '100g',
      allergens: ['milk', 'nuts', 'soybeans'],
      nutriScore: 'e',
      source: 'Open Food Facts',
    });

    const [[url, options]] = callsTo('world.openfoodfacts.org');
    expect(new URL(url).pathname).toBe(`/api/v2/product/${NUTELLA}.json`);
    expect(new URL(url).searchParams.get('fields')).toContain('allergens_tags');
    expect(options.headers['User-Agent']).toMatch(/^SuperFaster\/1\.0 /);

    // Deuxième recherche : réponse en cache, pas de nouvel appel.
    expect((await request(app).get(`/api/products/lookup/${NUTELLA}`).set(ADMIN)).status).toBe(200);
    expect(callsTo('world.openfoodfacts.org')).toHaveLength(1);
  });

  test('code-barres invalide : 422 sans appel réseau', async () => {
    for (const code of ['3017620422004', '30176204', '12345', 'abcdefghijklm']) {
      const res = await request(app).get(`/api/products/lookup/${code}`).set(OWNER);
      expect({ code, status: res.status }).toEqual({ code, status: 422 });
    }
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test('produit inconnu : 404, réponse gardée en cache', async () => {
    const unknown = '4006381333931';
    expect((await request(app).get(`/api/products/lookup/${unknown}`).set(OWNER)).status).toBe(404);
    expect((await request(app).get(`/api/products/lookup/${unknown}`).set(OWNER)).status).toBe(404);
    expect(callsTo('world.openfoodfacts.org')).toHaveLength(1);
  });

  test('Open Food Facts indisponible : 502, redemandé à l’appel suivant', async () => {
    fetchMock.mockImplementationOnce(async () => {
      throw new TypeError('fetch failed');
    });
    expect((await request(app).get(`/api/products/lookup/${NUTELLA}`).set(OWNER)).status).toBe(502);
    fetchMock.mockImplementationOnce(async () => json(500, {}));
    expect((await request(app).get(`/api/products/lookup/${NUTELLA}`).set(OWNER)).status).toBe(502);
    expect((await request(app).get(`/api/products/lookup/${NUTELLA}`).set(OWNER)).status).toBe(200);
  });

  test('droits : réservé aux restaurateurs et à l’admin', async () => {
    expect((await request(app).get(`/api/products/lookup/${NUTELLA}`).set(CLIENT)).status).toBe(403);
    expect((await request(app).get(`/api/products/lookup/${NUTELLA}`)).status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test('enregistrement : code-barres, Nutri-Score et allergènes validés, code unique par restaurant', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const product = {
      id: '',
      restaurantId: restaurant.id,
      name: 'Nutella 400 g',
      price: 4.2,
      section: 'Épicerie',
      barcode: '3017 6204 22003',
      nutriScore: 'E',
      allergens: ['milk', 'nuts', 'milk'],
    };
    const created = await request(app).post('/api/products').set(OWNER).send(product);
    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({ barcode: NUTELLA, nutriScore: 'e', allergens: ['milk', 'nuts'] });

    const post = (extra, target = restaurant.id) =>
      request(app).post('/api/products').set(ADMIN).send({ ...product, restaurantId: target, ...extra });
    expect((await post({})).status).toBe(409);
    expect((await post({ barcode: '3017620422004' })).status).toBe(422);
    expect((await post({ barcode: null, nutriScore: 'f' })).status).toBe(422);
    expect((await post({ barcode: null, allergens: ['peanut'] })).status).toBe(422);
    expect((await post({ barcode: null, allergens: 'milk' })).status).toBe(422);

    // Le même code-barres est permis dans un autre restaurant.
    const other = await createRestaurant();
    expect((await post({}, other.id)).status).toBe(201);

    // Aller-retour du formulaire, puis suppression du code-barres.
    const saved = await request(app).put(`/api/products/${created.body.id}`).set(OWNER).send(created.body);
    expect(saved.body).toMatchObject({ barcode: NUTELLA, nutriScore: 'e', allergens: ['milk', 'nuts'] });
    const cleared = await request(app)
      .put(`/api/products/${created.body.id}`)
      .set(OWNER)
      .send({ barcode: null, nutriScore: null, allergens: [] });
    expect(cleared.body).toMatchObject({ barcode: null, nutriScore: null, allergens: [] });
  });

  test('produits existants : aucun code-barres, Nutri-Score ni allergène', async () => {
    const demo = await request(app).get('/api/products/prod_1');
    expect(demo.body).toMatchObject({ barcode: null, nutriScore: null, allergens: [] });
  });
});
