'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const restaurantCatalogue = require('../src/restaurant_catalogue');

// Clés exactes de `toJson()` côté Flutter.
const RESTAURANT_KEYS = [
  'id', 'ownerId', 'name', 'description', 'cuisine', 'categoryIds', 'imageUrl', 'rating',
  'reviewCount', 'deliveryMinutes', 'deliveryFee', 'minOrder', 'distanceKm', 'address',
  'phone', 'menuSections', 'isOpen', 'isPopular', 'promo', 'status', 'createdAt',
];
const PRODUCT_KEYS = [
  'id', 'restaurantId', 'categoryId', 'name', 'description', 'price', 'imageUrl', 'section',
  'optionGroups', 'isAvailable', 'isPopular', 'calories',
];
const CATEGORY_KEYS = ['id', 'name', 'emoji', 'colorValue', 'position', 'isActive'];

const ADMIN = auth('u-admin');
const OWNER = auth('u-resto-1');
const CLIENT = auth('u-client-1');

function auth(userId) {
  return { Authorization: `Bearer mock-token-${userId}` };
}

function restaurantBody(extra = {}) {
  return {
    id: '',
    name: 'Chez Test',
    description: 'Cuisine maison',
    cuisine: 'Burgers • Américain',
    categoryIds: [],
    imageUrl: 'https://images.example.com/restaurant.jpg',
    address: '5 rue de Rivoli, 75004 Paris',
    phone: '0612345678',
    menuSections: ['Burgers', 'Boissons'],
    ...extra,
  };
}

function productBody(restaurantId, extra = {}) {
  return {
    id: '',
    restaurantId,
    categoryId: '',
    name: 'Classic',
    description: 'Bœuf, cheddar',
    price: 11.9,
    imageUrl: 'https://images.example.com/burger.jpg',
    section: 'Burgers',
    ...extra,
  };
}

async function createCategory(name, extra = {}) {
  const res = await request(app).post('/api/categories').set(ADMIN).send({ name, emoji: '🍔', ...extra });
  expect(res.status).toBe(201);
  return res.body;
}

async function createRestaurant(extra = {}, headers = ADMIN) {
  const res = await request(app).post('/api/restaurants').set(headers).send(restaurantBody(extra));
  expect(res.status).toBe(201);
  return res.body;
}

async function createProduct(restaurantId, extra = {}, headers = ADMIN) {
  const res = await request(app).post('/api/products').set(headers).send(productBody(restaurantId, extra));
  expect(res.status).toBe(201);
  return res.body;
}

/** Restaurateur actif créé par l'admin, sans restaurant. */
async function createRestaurateur(status = 'active') {
  const res = await request(app)
    .post('/api/users')
    .set(status === 'pending' ? {} : ADMIN)
    .send({
      firstName: 'Lina',
      lastName: 'Roux',
      email: `lina.${Date.now()}.${Math.random().toString(36).slice(2)}@exemple.fr`,
      phone: '0611111111',
      password: 'secret12',
      role: 'restaurant',
      ...(status === 'pending' ? {} : { status }),
    });
  expect(res.status).toBe(201);
  expect(res.body.status).toBe(status);
  return res.body;
}

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  await restaurantCatalogue.init();
  await query('DELETE FROM restaurant_categories');
  await query('DELETE FROM categories');
});

afterAll(async () => {
  await close();
});

// ── Catégories ──────────────────────────────────────────────────────────────

describe('catégories', () => {
  test('admin : création en dernière position, le public ne voit que les actives', async () => {
    const burgers = await createCategory('Burgers');
    expect(Object.keys(burgers).sort()).toEqual([...CATEGORY_KEYS].sort());
    expect(burgers).toMatchObject({ name: 'Burgers', emoji: '🍔', position: 0, isActive: true });
    expect(burgers.id).toMatch(/^cat_/);
    expect(burgers.colorValue).toBe(0xffffe8d9);

    const sushi = await createCategory('Sushi', { id: 'sushi', isActive: false, colorValue: 0xffe3f0ff });
    expect(sushi).toMatchObject({ id: 'sushi', position: 1, isActive: false, colorValue: 0xffe3f0ff });

    const publicList = await request(app).get('/api/categories');
    expect(publicList.status).toBe(200);
    expect(publicList.body.map((c) => c.id)).toEqual([burgers.id]);

    const adminList = await request(app).get('/api/categories').set(ADMIN);
    expect(adminList.body.map((c) => c.id)).toEqual([burgers.id, 'sushi']);

    expect((await request(app).get('/api/categories/sushi')).status).toBe(404);
    expect((await request(app).get('/api/categories/sushi').set(ADMIN)).status).toBe(200);
  });

  test('droits : création réservée à l’admin', async () => {
    const body = { name: 'Tacos', emoji: '🌮' };
    expect((await request(app).post('/api/categories').send(body)).status).toBe(401);
    expect((await request(app).post('/api/categories').set(CLIENT).send(body)).status).toBe(403);
    expect((await request(app).post('/api/categories').set(OWNER).send(body)).status).toBe(403);
  });

  test('validation : nom obligatoire et unique, couleur et identifiant valides', async () => {
    await createCategory('Burgers', { id: 'burger' });
    const post = (body) => request(app).post('/api/categories').set(ADMIN).send(body);

    expect((await post({ name: '' })).status).toBe(422);
    expect((await post({ name: 'BURGERS' })).status).toBe(409);
    expect((await post({ name: 'Pizza', id: 'burger' })).status).toBe(409);
    expect((await post({ name: 'Pizza', id: 'mauvais id!' })).status).toBe(422);
    expect((await post({ name: 'Pizza', colorValue: -1 })).status).toBe(422);
    expect((await post({ name: 'Pizza', colorValue: 0x1ffffffff })).status).toBe(422);
    expect((await post({ name: 'Pizza', isActive: 'oui' })).status).toBe(422);

    const pizza = await post({ name: 'Pizza' });
    expect(pizza.status).toBe(201);
    expect(pizza.body.emoji).toBe('🍽️');
  });

  test('modification : nom, emoji et activation ; la position ne change pas', async () => {
    await createCategory('Burgers');
    const pizza = await createCategory('Pizza');
    const res = await request(app)
      .put(`/api/categories/${pizza.id}`)
      .set(ADMIN)
      .send({ ...pizza, name: 'Italien', emoji: '🍕', isActive: false, position: 0 });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ name: 'Italien', emoji: '🍕', isActive: false, position: 1 });

    const duplicate = await request(app).put(`/api/categories/${pizza.id}`).set(ADMIN).send({ name: 'burgers' });
    expect(duplicate.status).toBe(409);
    expect((await request(app).put('/api/categories/inconnue').set(ADMIN).send({ name: 'X1' })).status).toBe(404);
  });

  test('réordonnancement (glisser-déposer du back office)', async () => {
    const a = await createCategory('A1');
    const b = await createCategory('B1');
    const c = await createCategory('C1');

    const res = await request(app).put('/api/categories/order').set(ADMIN).send({ ids: [c.id, a.id] });
    expect(res.status).toBe(200);
    expect(res.body.map((cat) => [cat.id, cat.position])).toEqual([
      [c.id, 0],
      [a.id, 1],
      [b.id, 2],
    ]);

    const order = (ids, headers = ADMIN) => request(app).put('/api/categories/order').set(headers).send({ ids });
    expect((await order([a.id, 'inconnue'])).status).toBe(422);
    expect((await order([a.id, a.id])).status).toBe(422);
    expect((await order([])).status).toBe(422);
    expect((await order([a.id], OWNER)).status).toBe(403);
  });

  test('suppression : retirée des restaurants et des produits, ordre recompacté', async () => {
    const a = await createCategory('A1');
    const b = await createCategory('B1');
    const c = await createCategory('C1');
    const restaurant = await createRestaurant({ categoryIds: [a.id, b.id] });
    const product = await createProduct(restaurant.id, { categoryId: a.id });

    expect((await request(app).delete(`/api/categories/${a.id}`).set(CLIENT)).status).toBe(403);
    expect((await request(app).delete(`/api/categories/${a.id}`).set(ADMIN)).status).toBe(204);

    const after = await request(app).get(`/api/restaurants/${restaurant.id}`).set(ADMIN);
    expect(after.body.categoryIds).toEqual([b.id]);
    const productAfter = await request(app).get(`/api/products/${product.id}`).set(ADMIN);
    expect(productAfter.body.categoryId).toBe('');

    const list = await request(app).get('/api/categories').set(ADMIN);
    expect(list.body.map((cat) => [cat.id, cat.position])).toEqual([
      [b.id, 0],
      [c.id, 1],
    ]);
    expect((await request(app).delete(`/api/categories/${a.id}`).set(ADMIN)).status).toBe(404);
  });
});

// ── Restaurants ─────────────────────────────────────────────────────────────

describe('restaurants', () => {
  test('inscription Espace Pro : demande en attente, fermée et invisible du public', async () => {
    const owner = await createRestaurateur('pending');

    const created = await request(app)
      .post('/api/restaurants')
      .send(restaurantBody({ ownerId: owner.id, status: 'approved', isPopular: true, rating: 5 }));
    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({
      ownerId: owner.id,
      status: 'pending',
      isOpen: false,
      isPopular: false,
      rating: 0,
    });
    expect(created.body.id).toMatch(/^rest_/);
    expect(Object.keys(created.body)).toEqual(expect.arrayContaining(RESTAURANT_KEYS));
    expect(new Date(created.body.createdAt).toISOString()).toBe(created.body.createdAt);

    const publicList = await request(app).get('/api/restaurants');
    expect(publicList.body.map((r) => r.id)).not.toContain(created.body.id);
    expect((await request(app).get(`/api/restaurants/${created.body.id}`)).status).toBe(404);

    const adminList = await request(app).get('/api/restaurants').set(ADMIN);
    expect(adminList.body.map((r) => r.id)).toContain(created.body.id);
    const pending = await request(app).get('/api/restaurants').query({ status: 'pending' }).set(ADMIN);
    expect(pending.body.map((r) => r.id)).toEqual([created.body.id]);

    // Un restaurateur ne gère qu'un restaurant.
    const again = await request(app).post('/api/restaurants').send(restaurantBody({ ownerId: owner.id }));
    expect(again.status).toBe(409);
  });

  test('inscription anonyme : compte restaurateur en attente obligatoire', async () => {
    const post = (body, headers = {}) => request(app).post('/api/restaurants').set(headers).send(body);
    expect((await post(restaurantBody())).status).toBe(422);
    expect((await post(restaurantBody({ ownerId: 'u-resto-1' }))).status).toBe(422);
    expect((await post(restaurantBody({ ownerId: 'u-client-1' }))).status).toBe(422);
    expect((await post(restaurantBody({ ownerId: 'inconnu' }))).status).toBe(422);
    expect((await post(restaurantBody(), CLIENT)).status).toBe(403);
  });

  test('restaurateur connecté : sa demande est en attente et lui appartient', async () => {
    const res = await request(app)
      .post('/api/restaurants')
      .set(OWNER)
      .send(restaurantBody({ ownerId: 'u-admin', status: 'approved' }));
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ ownerId: 'u-resto-1', status: 'pending', isOpen: false });

    // Il voit sa demande, le public non.
    expect((await request(app).get(`/api/restaurants/${res.body.id}`).set(OWNER)).status).toBe(200);
    const mine = await request(app).get('/api/restaurants').set(OWNER);
    expect(mine.body.map((r) => r.id)).toContain(res.body.id);
    expect((await request(app).get(`/api/restaurants/${res.body.id}`).set(CLIENT)).status).toBe(404);
  });

  test('admin : validation, suspension et réactivation (PATCH /status)', async () => {
    const restaurant = await createRestaurant({ status: 'pending' });
    expect(restaurant).toMatchObject({ status: 'pending', isOpen: false });

    const patch = (status, headers = ADMIN, id = restaurant.id) =>
      request(app).patch(`/api/restaurants/${id}/status`).set(headers).send({ status });

    const approved = await patch('approved');
    expect(approved.status).toBe(200);
    expect(approved.body).toMatchObject({ status: 'approved', isOpen: true });
    expect((await request(app).get(`/api/restaurants/${restaurant.id}`)).status).toBe(200);

    const suspended = await patch('suspended');
    expect(suspended.body).toMatchObject({ status: 'suspended', isOpen: false });
    expect((await request(app).get(`/api/restaurants/${restaurant.id}`)).status).toBe(404);

    expect((await patch('approved')).body).toMatchObject({ status: 'approved', isOpen: true });
    expect((await patch('rejected')).body).toMatchObject({ status: 'rejected', isOpen: false });

    expect((await patch('bogus')).status).toBe(422);
    expect((await patch('approved', OWNER)).status).toBe(403);
    expect((await request(app).patch(`/api/restaurants/${restaurant.id}/status`).send({ status: 'approved' })).status).toBe(401);
    expect((await patch('approved', ADMIN, 'inconnu')).status).toBe(404);
  });

  test('admin : catégories du restaurant et filtre ?categoryId=', async () => {
    const a = await createCategory('A1');
    const b = await createCategory('B1');
    const both = await createRestaurant({ categoryIds: [b.id, a.id, b.id] });
    expect(both.categoryIds).toEqual([a.id, b.id]);
    const none = await createRestaurant();

    const byA = await request(app).get('/api/restaurants').query({ categoryId: a.id });
    expect(byA.body.map((r) => r.id)).toEqual([both.id]);
    const all = await request(app).get('/api/restaurants');
    expect(all.body.map((r) => r.id)).toEqual(expect.arrayContaining([both.id, none.id]));

    const unknown = await request(app).post('/api/restaurants').set(ADMIN).send(restaurantBody({ categoryIds: ['inconnue'] }));
    expect(unknown.status).toBe(422);
  });

  test('restaurateur : modifie son restaurant, les champs réservés sont ignorés', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const res = await request(app)
      .put(`/api/restaurants/${restaurant.id}`)
      .set(OWNER)
      .send({
        ...restaurant,
        name: 'Chez Test 2',
        menuSections: ['Entrées', 'Plats'],
        deliveryFee: 2.49,
        minOrder: 0,
        promo: '-20 %',
        isOpen: false,
        status: 'suspended',
        isPopular: true,
        rating: 5,
        reviewCount: 99,
        ownerId: 'u-admin',
      });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      name: 'Chez Test 2',
      menuSections: ['Entrées', 'Plats'],
      deliveryFee: 2.49,
      minOrder: 0,
      promo: '-20 %',
      isOpen: false,
      status: 'approved',
      isPopular: false,
      rating: 0,
      reviewCount: 0,
      ownerId: 'u-resto-1',
    });

    const other = await createRestaurateur();
    const put = (headers) => request(app).put(`/api/restaurants/${restaurant.id}`).set(headers).send({ name: 'Piraté' });
    expect((await put(auth(other.id))).status).toBe(403);
    expect((await put(CLIENT)).status).toBe(403);
    expect((await request(app).put(`/api/restaurants/${restaurant.id}`).send({ name: 'Piraté' })).status).toBe(401);
  });

  test('admin : statut, mise en avant et propriétaire modifiables par le formulaire', async () => {
    const restaurant = await createRestaurant();
    const owner = await createRestaurateur();
    const res = await request(app)
      .put(`/api/restaurants/${restaurant.id}`)
      .set(ADMIN)
      .send({ ...restaurant, isPopular: true, ownerId: owner.id, status: 'suspended', isOpen: true });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ isPopular: true, ownerId: owner.id, status: 'suspended', isOpen: false });

    const second = await createRestaurant();
    const taken = await request(app).put(`/api/restaurants/${second.id}`).set(ADMIN).send({ ownerId: owner.id });
    expect(taken.status).toBe(409);
  });

  test('validation des champs', async () => {
    const post = (extra) => request(app).post('/api/restaurants').set(ADMIN).send(restaurantBody(extra));
    for (const extra of [
      { name: 'A' },
      { cuisine: '' },
      { address: '   ' },
      { phone: '12' },
      { email: 'pas-un-email' },
      { deliveryFee: -1 },
      { deliveryMinutes: 2.5 },
      { minOrder: 'beaucoup' },
      { imageUrl: 'ftp://images.example.com/r.jpg' },
      { menuSections: 'Burgers' },
      { isOpen: 'oui' },
      { status: 'ouvert' },
      { id: 'id invalide' },
    ]) {
      const res = await post(extra);
      expect({ extra, status: res.status }).toEqual({ extra, status: 422 });
      expect(res.body.error).toEqual(expect.any(String));
    }
  });

  test('suppression (admin) : le menu part avec le restaurant', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const product = await createProduct(restaurant.id);

    expect((await request(app).delete(`/api/restaurants/${restaurant.id}`).set(OWNER)).status).toBe(403);
    expect((await request(app).delete(`/api/restaurants/${restaurant.id}`).set(ADMIN)).status).toBe(204);
    expect((await request(app).get(`/api/restaurants/${restaurant.id}`).set(ADMIN)).status).toBe(404);
    expect((await request(app).get(`/api/products/${product.id}`).set(ADMIN)).status).toBe(404);
    expect((await request(app).delete(`/api/restaurants/${restaurant.id}`).set(ADMIN)).status).toBe(404);
  });

  test('restaurant de démo existant : visible, modifiable et toujours commandable', async () => {
    const demo = await request(app).get('/api/restaurants/rest_demo');
    expect(demo.status).toBe(200);
    expect(demo.body).toMatchObject({ name: 'SuperBurger Demo', status: 'approved', isOpen: true, cuisine: 'burgers' });

    const menu = await request(app).get('/api/restaurants/rest_demo/products');
    expect(menu.status).toBe(200);
    expect(menu.body.map((p) => [p.id, p.section])).toEqual([
      ['prod_1', 'burgers'],
      ['prod_2', 'burgers'],
      ['prod_3', 'sides'],
      ['prod_4', 'drinks'],
    ]);

    const saved = await request(app).put('/api/restaurants/rest_demo').set(ADMIN).send(demo.body);
    expect(saved.status).toBe(200);

    // Le module Commandes lit toujours restaurants / products normalement.
    const order = await request(app)
      .post('/api/orders')
      .send({
        userId: 'u-client-1',
        restaurantId: 'rest_demo',
        deliveryAddress: '12 rue de la Paix, Paris',
        items: [{ productId: 'prod_1', quantity: 1 }],
      });
    expect(order.status).toBe(201);
    expect(order.body.items[0]).toMatchObject({ productId: 'prod_1', price: 9.9 });
  });
});

// ── Produits ────────────────────────────────────────────────────────────────

describe('produits', () => {
  test('restaurateur : produit avec options, forme JSON du modèle Flutter', async () => {
    const category = await createCategory('Burgers');
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const res = await request(app)
      .post('/api/products')
      .set(OWNER)
      .send(
        productBody(restaurant.id, {
          categoryId: category.id,
          price: '12.499',
          isPopular: true,
          calories: 850,
          optionGroups: [
            {
              id: '',
              name: 'Taille',
              isRequired: true,
              maxChoices: 1,
              options: [
                { id: '', name: 'Normal', price: 0 },
                { id: '', name: 'XL', price: 2.5 },
              ],
            },
          ],
        }),
      );
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual([...PRODUCT_KEYS].sort());
    expect(res.body).toMatchObject({
      restaurantId: restaurant.id,
      categoryId: category.id,
      price: 12.5,
      section: 'Burgers',
      isAvailable: true,
      isPopular: true,
      calories: 850,
    });
    expect(res.body.id).toMatch(/^prod_/);
    const [group] = res.body.optionGroups;
    expect(group).toMatchObject({ name: 'Taille', isRequired: true, maxChoices: 1 });
    expect(group.id).toMatch(/^grp_/);
    expect(group.options.map((o) => o.id)).toEqual([expect.stringMatching(/^opt_/), expect.stringMatching(/^opt_/)]);

    // Aller-retour du formulaire : les identifiants des options sont conservés.
    const updated = await request(app)
      .put(`/api/products/${res.body.id}`)
      .set(OWNER)
      .send({ ...res.body, price: 13, calories: null });
    expect(updated.status).toBe(200);
    expect(updated.body).toMatchObject({ price: 13, calories: null });
    expect(updated.body.optionGroups).toEqual(res.body.optionGroups);

    const menu = await request(app).get(`/api/restaurants/${restaurant.id}/products`);
    expect(menu.body.map((p) => p.id)).toEqual([res.body.id]);
  });

  test('validation des produits', async () => {
    const restaurant = await createRestaurant();
    const option = (name, price = 0) => ({ id: '', name, price });
    const post = (extra) => request(app).post('/api/products').set(ADMIN).send(productBody(restaurant.id, extra));
    for (const extra of [
      { price: 0 },
      { price: 'abc' },
      { price: null },
      { section: '' },
      { name: '' },
      { calories: -5 },
      { calories: 1.5 },
      { categoryId: 'inconnue' },
      { imageUrl: 'javascript:alert(1)' },
      { isAvailable: 'oui' },
      { optionGroups: 'Taille' },
      { optionGroups: [{ name: 'Taille', options: [] }] },
      { optionGroups: [{ name: 'Taille', maxChoices: 3, options: [option('S'), option('M')] }] },
      { optionGroups: [{ name: '', options: [option('S')] }] },
      { optionGroups: [{ name: 'Taille', options: [option('S', -1)] }] },
      { optionGroups: [{ name: 'Taille', options: [{ id: 'x', name: 'S' }, { id: 'x', name: 'M' }] }] },
    ]) {
      const res = await post(extra);
      expect({ extra, status: res.status }).toEqual({ extra, status: 422 });
    }
    expect((await post({ restaurantId: '' })).status).toBe(422);
    expect((await post({ restaurantId: 'inconnu' })).status).toBe(422);
  });

  test('droits : un autre restaurateur, un client ou un anonyme ne gèrent pas le menu', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const product = await createProduct(restaurant.id, {}, OWNER);
    const other = auth((await createRestaurateur()).id);

    const post = (headers) => request(app).post('/api/products').set(headers).send(productBody(restaurant.id));
    expect((await post(other)).status).toBe(403);
    expect((await post(CLIENT)).status).toBe(403);
    expect((await request(app).post('/api/products').send(productBody(restaurant.id))).status).toBe(401);

    const url = `/api/products/${product.id}`;
    expect((await request(app).put(url).set(other).send({ price: 1 })).status).toBe(403);
    expect((await request(app).patch(`${url}/availability`).set(other).send({ isAvailable: false })).status).toBe(403);
    expect((await request(app).delete(url).set(other)).status).toBe(403);

    // Déplacer un produit vers un autre restaurant : admin seulement.
    const target = await createRestaurant();
    expect((await request(app).put(url).set(OWNER).send({ restaurantId: target.id })).status).toBe(403);
    const moved = await request(app).put(url).set(ADMIN).send({ restaurantId: target.id });
    expect(moved.status).toBe(200);
    expect(moved.body.restaurantId).toBe(target.id);

    expect((await request(app).delete(url).set(ADMIN)).status).toBe(204);
    expect((await request(app).delete(url).set(ADMIN)).status).toBe(404);
  });

  test('disponibilité : interrupteur du back office et filtre ?available=', async () => {
    const restaurant = await createRestaurant({ ownerId: 'u-resto-1' });
    const product = await createProduct(restaurant.id);
    const url = `/api/products/${product.id}/availability`;

    const res = await request(app).patch(url).set(OWNER).send({ isAvailable: false });
    expect(res.status).toBe(200);
    expect(res.body.isAvailable).toBe(false);
    expect((await request(app).patch(url).set(OWNER).send({ isAvailable: 'non' })).status).toBe(422);
    expect((await request(app).patch(url).set(OWNER).send({})).status).toBe(422);

    const soldOut = await request(app).get('/api/products').query({ available: 'false', restaurantId: restaurant.id });
    expect(soldOut.body.map((p) => p.id)).toEqual([product.id]);
    expect((await request(app).get('/api/products').query({ available: 'peut-être' })).status).toBe(422);
  });

  test('visibilité : le menu d’un restaurant non validé est caché au public', async () => {
    const restaurant = await createRestaurant({ status: 'pending' });
    const product = await createProduct(restaurant.id);

    expect((await request(app).get(`/api/restaurants/${restaurant.id}/products`)).status).toBe(404);
    expect((await request(app).get(`/api/products/${product.id}`)).status).toBe(404);
    expect((await request(app).get('/api/products')).body.map((p) => p.id)).not.toContain(product.id);
    expect((await request(app).get('/api/products').set(ADMIN)).body.map((p) => p.id)).toContain(product.id);
    expect((await request(app).get('/api/products/inconnu')).status).toBe(404);
  });

  test('produit de démo existant : l’ancienne catégorie inchangée ne bloque pas la sauvegarde', async () => {
    const demo = await request(app).get('/api/products/prod_1');
    expect(demo.status).toBe(200);
    expect(demo.body).toMatchObject({ categoryId: 'burgers', section: 'burgers', price: 9.9 });

    const saved = await request(app).put('/api/products/prod_1').set(ADMIN).send({ ...demo.body, price: 10.5 });
    expect(saved.status).toBe(200);
    expect(saved.body).toMatchObject({ categoryId: 'burgers', price: 10.5 });
  });
});
