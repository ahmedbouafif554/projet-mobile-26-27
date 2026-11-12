'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const helpers = require('./helpers');

const { as, ADMIN, ALEX, KARIM, ADDRESS } = helpers;

/** Commande type de ce fichier : un Classic Burger taille normale (9,90 €). */
function placeOrder(appInstance, extra = {}, headers = ALEX) {
  return helpers.placeOrder(
    appInstance,
    { items: [{ product: { id: 'prod_1' }, quantity: 1, options: [{ id: 'o-normal' }] }], ...extra },
    headers,
  );
}

const RESTO = as('u-resto-1');
const OTHER_CLIENT = as('u-client-2');

/** Groupes d'options du Classic Burger (prod_1, 9,90 €). */
const OPTION_GROUPS = [
  {
    id: 'g-size',
    name: 'Taille',
    isRequired: true,
    maxChoices: 1,
    options: [
      { id: 'o-normal', name: 'Normal', price: 0 },
      { id: 'o-xl', name: 'XL', price: 2 },
    ],
  },
  {
    id: 'g-extra',
    name: 'Suppléments',
    isRequired: false,
    maxChoices: 2,
    options: [
      { id: 'o-bacon', name: 'Bacon', price: 1.5 },
      { id: 'o-cheddar', name: 'Cheddar', price: 1 },
      { id: 'o-egg', name: 'Œuf', price: 1 },
    ],
  },
];

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  await query('UPDATE products SET option_groups = ? WHERE id = ?', [JSON.stringify(OPTION_GROUPS), 'prod_1']);
  // Le restaurant de démo appartient à Marc (u-resto-1).
  await query("UPDATE restaurants SET owner_id = 'u-resto-1' WHERE id = 'rest_demo'");
  await query(
    `INSERT INTO users (id, first_name, last_name, email, phone, role, status, loyalty_points, created_at)
     VALUES ('u-client-2', 'Inès', 'Roy', 'ines.roy@exemple.fr', '0611111111', 'client', 'active', 0, ?)`,
    [new Date().toISOString()],
  );
});

afterAll(async () => {
  await close();
});

function addToCart(body, headers = ALEX) {
  return request(app).post('/api/cart/items').set(headers).send(body);
}

const burger = (extra = {}) => ({
  id: '',
  product: { id: 'prod_1', restaurantId: 'rest_demo', name: 'Classic Burger', price: 9.9 },
  quantity: 1,
  options: [{ id: 'o-normal', name: 'Normal', price: 0 }],
  note: null,
  ...extra,
});

async function setStatus(orderId, status, headers = ADMIN, note) {
  return request(app).patch(`/api/orders/${orderId}/status`).set(headers).send({ status, note });
}

describe('Panier — /api/cart/items', () => {
  test('session obligatoire ; chaque compte a son propre panier', async () => {
    expect((await request(app).get('/api/cart/items')).status).toBe(401);
    expect((await request(app).get('/api/cart/items').query({ userId: 'u-client-1' })).status).toBe(401);

    const added = await addToCart(burger());
    expect(added.status).toBe(201);

    // Un autre compte ne voit ni ne modifie le panier d'Alex, même avec ?userId=.
    const other = await request(app).get('/api/cart/items').set(OTHER_CLIENT).query({ userId: 'u-client-1' });
    expect(other.body).toEqual([]);
    const steal = await request(app).put(`/api/cart/items/${added.body.id}`).set(OTHER_CLIENT).send({ quantity: 5 });
    expect(steal.status).toBe(404);
    expect((await request(app).delete(`/api/cart/items/${added.body.id}`).set(OTHER_CLIENT)).status).toBe(200);
    expect((await request(app).get('/api/cart/items').set(ALEX)).body).toHaveLength(1);
  });

  test('prix et options relus en base : le prix envoyé par l’application est ignoré', async () => {
    const added = await addToCart(
      burger({
        product: { id: 'prod_1', restaurantId: 'rest_demo', name: 'Burger gratuit', price: 0.01 },
        quantity: 2,
        options: [
          { id: 'o-xl', name: 'XL', price: 0 },
          { id: 'o-bacon', name: 'Bacon', price: 0 },
        ],
        note: '  Sans oignons  ',
      }),
    );
    expect(added.status).toBe(201);
    expect(added.body.id).toMatch(/^ci_/);
    expect(added.body.product).toMatchObject({ id: 'prod_1', name: 'Classic Burger', price: 9.9 });
    expect(added.body.options).toEqual([
      { id: 'o-xl', name: 'XL', price: 2 },
      { id: 'o-bacon', name: 'Bacon', price: 1.5 },
    ]);
    expect(added.body.note).toBe('Sans oignons');
    expect(added.body.unitPrice).toBe(13.4);
    expect(added.body.totalPrice).toBe(26.8);

    // Le PUT complet du front (CartItem.toJson) ne change pas le prix non plus.
    const put = await request(app)
      .put(`/api/cart/items/${added.body.id}`)
      .set(ALEX)
      .send({ ...added.body, product: { ...added.body.product, price: 1 }, quantity: 3 });
    expect(put.status).toBe(200);
    expect(put.body.quantity).toBe(3);
    expect(put.body.product.price).toBe(9.9);
    expect(put.body.totalPrice).toBe(40.2);
  });

  test('options validées : inconnues, choix obligatoire, nombre maximum', async () => {
    const unknown = await addToCart(burger({ options: [{ id: 'o-normal' }, { id: 'o-caviar', price: 0 }] }));
    expect(unknown.status).toBe(422);
    const missing = await addToCart(burger({ options: [] }));
    expect(missing.status).toBe(422);
    expect(missing.body.error).toMatch(/Taille/);
    const tooMany = await addToCart(burger({ options: [{ id: 'o-normal' }, { id: 'o-bacon' }, { id: 'o-cheddar' }, { id: 'o-egg' }] }));
    expect(tooMany.status).toBe(422);
    expect(tooMany.body.error).toMatch(/2 choix maximum/);
    const twoSizes = await addToCart(burger({ options: [{ id: 'o-normal' }, { id: 'o-xl' }] }));
    expect(twoSizes.status).toBe(422);
  });

  test('fusion des lignes identiques, quantités, suppression et vidage', async () => {
    const first = await addToCart(burger({ options: [{ id: 'o-normal' }, { id: 'o-bacon' }, { id: 'o-egg' }], note: 'Bien cuit' }));
    // Mêmes options dans un autre ordre, même note : même ligne.
    const again = await addToCart(burger({ options: [{ id: 'o-egg' }, { id: 'o-bacon' }, { id: 'o-normal' }], note: 'Bien cuit', quantity: 2 }));
    expect(again.body.id).toBe(first.body.id);
    expect(again.body.quantity).toBe(3);
    // Note différente : nouvelle ligne.
    const other = await addToCart(burger({ note: 'Saignant' }));
    expect(other.body.id).not.toBe(first.body.id);
    const fries = await addToCart({ product: { id: 'prod_3' }, quantity: 1 });
    expect(fries.status).toBe(201);
    expect((await request(app).get('/api/cart/items').set(ALEX)).body).toHaveLength(3);

    expect((await request(app).put(`/api/cart/items/${fries.body.id}`).set(ALEX).send({ quantity: 100 })).status).toBe(422);
    const removed = await request(app).put(`/api/cart/items/${fries.body.id}`).set(ALEX).send({ quantity: 0 });
    expect(removed.body).toEqual({ id: fries.body.id, deleted: true });
    expect((await request(app).get(`/api/cart/items/${fries.body.id}`).set(ALEX)).status).toBe(404);

    expect((await request(app).delete(`/api/cart/items/${other.body.id}`).set(ALEX)).status).toBe(200);
    expect((await request(app).delete('/api/cart/items').set(ALEX)).status).toBe(200);
    expect((await request(app).get('/api/cart/items').set(ALEX)).body).toEqual([]);
  });

  test('un seul restaurant par panier ; produit indisponible ou inconnu refusé', async () => {
    await query(
      `INSERT INTO restaurants (id, name, address, latitude, longitude, is_open, status, delivery_fee, min_order, created_at)
       VALUES ('rest_b', 'Sushi B', '1 rue B', 48.86, 2.34, 1, 'approved', 1.5, 0, ?)`,
      [new Date().toISOString()],
    );
    await query("INSERT INTO products (id, restaurant_id, name, price, is_available, created_at) VALUES ('prod_b', 'rest_b', 'Maki', 6, 1, ?)", [new Date().toISOString()]);

    await addToCart(burger());
    const conflict = await addToCart({ product: { id: 'prod_b' }, quantity: 1 });
    expect(conflict.status).toBe(409);
    expect(conflict.body.error).toMatch(/autre restaurant/);

    const replaced = await addToCart({ product: { id: 'prod_b' }, quantity: 1, replace: true });
    expect(replaced.status).toBe(201);
    const cart = (await request(app).get('/api/cart/items').set(ALEX)).body;
    expect(cart.map((i) => i.product.id)).toEqual(['prod_b']);

    await query("UPDATE products SET is_available = 0 WHERE id = 'prod_b'");
    expect((await addToCart({ product: { id: 'prod_b' } })).status).toBe(409);
    expect((await addToCart({ product: { id: 'nope' } })).status).toBe(404);
    expect((await addToCart({ quantity: 1 })).status).toBe(422);

    // Un produit devenu indisponible reste visible dans le panier, marqué indisponible.
    expect((await request(app).get('/api/cart/items').set(ALEX)).body[0].product.isAvailable).toBe(false);
  });

  test('totaux et codes promo identiques au front (CartTotals, PromoCodes)', async () => {
    await addToCart(burger({ quantity: 2, options: [{ id: 'o-normal' }, { id: 'o-cheddar' }] })); // 2 × 10,90
    await addToCart({ product: { id: 'prod_3' }, quantity: 1 }); // 3,50

    const plain = (await request(app).get('/api/cart/totals').set(ALEX)).body;
    expect(plain).toMatchObject({
      subtotal: 25.3,
      deliveryFee: 2.5,
      serviceFee: 1.27,
      discount: 0,
      total: 29.07,
      itemCount: 3,
      restaurantId: 'rest_demo',
      minOrder: 5,
      isOpen: true,
    });

    const totals = async (promoCode) => (await request(app).get('/api/cart/totals').set(ALEX).query({ promoCode })).body;
    expect((await totals('super10')).discount).toBe(2.53);
    expect((await totals('BIENVENUE')).discount).toBe(5);
    expect((await totals('LIVRAISON')).discount).toBe(2.5);
    const invalid = await totals('FAUX');
    expect(invalid.promoValid).toBe(false);
    expect(invalid.discount).toBe(0);
  });
});

describe('Commandes — création', () => {
  test('depuis le panier : montants recalculés, panier vidé, référence SF', async () => {
    await addToCart(burger({ quantity: 2, options: [{ id: 'o-xl' }] })); // 2 × 11,90
    await addToCart({ product: { id: 'prod_3' }, quantity: 1 }); // 3,50
    const cart = (await request(app).get('/api/cart/items').set(ALEX)).body;

    const res = await placeOrder(app, {
      userId: 'u-admin', // ignoré : la commande est celle du compte connecté
      items: cart.map((item) => ({ ...item, product: { ...item.product, price: 0 } })),
      deliveryFee: 0,
      serviceFee: 0,
      discount: 999,
      paymentStatus: 'paid',
      promoCode: 'bienvenue',
      note: 'Sonner deux fois',
    });
    expect(res.status).toBe(201);
    const order = res.body;
    expect(order.id).toMatch(/^ord_/);
    expect(order.reference).toMatch(/^SF\d{4,}$/);
    expect(order).toMatchObject({
      userId: 'u-client-1',
      customerName: 'Alex Martin',
      restaurantId: 'rest_demo',
      restaurantName: 'SuperBurger Demo',
      status: 'pending',
      subtotal: 27.3,
      deliveryFee: 2.5,
      serviceFee: 1.37,
      discount: 5,
      totalAmount: 26.17,
      promoCode: 'BIENVENUE',
      paymentMethod: 'cash',
      paymentStatus: 'pending',
      note: 'Sonner deux fois',
    });
    expect(order.items).toHaveLength(2);
    expect(order.items[0]).toMatchObject({ productId: 'prod_1', price: 11.9, quantity: 2 });
    expect(order.items[0].options).toEqual([{ id: 'o-xl', name: 'XL', price: 2 }]);
    expect(order.deliveryAddress).toMatchObject({ street: '12 rue de la Paix', city: 'Paris', latitude: 48.8686 });
    expect(order.history.map((e) => e.status)).toEqual(['pending']);

    expect((await request(app).get('/api/cart/items').set(ALEX)).body).toEqual([]);
    // La course est proposée aux livreurs dès la commande.
    const deliveries = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.id })).body;
    expect(deliveries).toHaveLength(1);
    expect(deliveries[0]).toMatchObject({ status: 'waiting', courierId: null });

    // Espèces uniquement : carte et Apple Pay refusés.
    for (const paymentMethod of ['card', 'applePay']) {
      const refused = await placeOrder(app, { paymentMethod });
      expect(refused.status).toBe(422);
      expect(refused.body.error).toBe('Seul le paiement en espèces à la livraison est disponible.');
    }
    const next = await placeOrder(app);
    expect(next.body).toMatchObject({ paymentMethod: 'cash', paymentStatus: 'pending' });
    expect(Number(next.body.reference.slice(2))).toBe(Number(order.reference.slice(2)) + 1);
  });

  test('refus : session, rôle, promo, minimum, restaurant fermé, produit étranger, adresse', async () => {
    expect((await request(app).post('/api/orders').send({ restaurantId: 'rest_demo' })).status).toBe(401);
    expect((await placeOrder(app, {}, KARIM)).status).toBe(403);
    expect((await placeOrder(app, { items: [] })).status).toBe(422);
    expect((await placeOrder(app, { promoCode: 'GRATUIT' })).body.error).toBe('Code promo invalide.');
    // BIENVENUE exige 15 € d'articles.
    expect((await placeOrder(app, { promoCode: 'BIENVENUE' })).status).toBe(422);

    const small = await placeOrder(app, { items: [{ product: { id: 'prod_4' }, quantity: 1 }] }); // 2,50 € < 5 €
    expect(small.status).toBe(422);
    expect(small.body.error).toBe('Le minimum de commande est de 5,00 €.');

    expect((await placeOrder(app, { paymentMethod: 'bitcoin' })).status).toBe(422);
    expect((await placeOrder(app, { deliveryAddress: { street: '', city: 'Paris' } })).status).toBe(422);
    expect((await placeOrder(app, { deliveryAddress: 'texte libre' })).status).toBe(422);
    expect((await placeOrder(app, { deliveryAddress: { ...ADDRESS, latitude: 200 } })).status).toBe(422);
    // Adresse d'un autre compte.
    expect((await placeOrder(app, {}, OTHER_CLIENT)).status).toBe(403);

    await query("INSERT INTO products (id, restaurant_id, name, price, is_available, created_at) VALUES ('prod_x', 'ailleurs', 'X', 6, 1, ?)", [new Date().toISOString()]);
    expect((await placeOrder(app, { items: [{ product: { id: 'prod_x' }, quantity: 2 }] })).status).toBe(422);

    await query("UPDATE restaurants SET is_open = 0 WHERE id = 'rest_demo'");
    const closed = await placeOrder(app);
    expect(closed.status).toBe(409);
    expect(closed.body.error).toBe('SuperBurger Demo est fermé pour le moment.');
  });

  test('commande par téléphone (restaurateur) : client invité, frais fixes', async () => {
    const res = await placeOrder(
      app,
      {
        userId: 'guest',
        customerName: 'Mme Durand',
        customerPhone: '0600000000',
        deliveryAddress: { id: '', userId: 'guest', label: 'Livraison', street: '3 rue X', postalCode: '75011', city: 'Paris' },
        items: [{ id: 'prod_1', product: { id: 'prod_1' }, quantity: 1, options: [{ id: 'o-normal' }] }],
        paymentMethod: 'cash',
        serviceFee: 0.99,
      },
      RESTO,
    );
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      userId: 'guest',
      customerName: 'Mme Durand',
      customerPhone: '0600000000',
      serviceFee: 0.99,
      deliveryFee: 2.5,
      totalAmount: 13.39,
      paymentStatus: 'pending',
    });
    expect(res.body.history[0].note).toBe('Commande saisie par téléphone.');

    // Un restaurateur ne saisit pas de commande pour un autre restaurant.
    await query("UPDATE restaurants SET owner_id = NULL WHERE id = 'rest_demo'");
    expect((await placeOrder(app, {}, RESTO)).status).toBe(403);
  });
});

describe('Commandes — lecture et cycle de vie', () => {
  test('chacun ne voit que ses commandes', async () => {
    const order = (await placeOrder(app)).body;
    expect((await request(app).get(`/api/orders/${order.id}`)).status).toBe(401);
    expect((await request(app).get(`/api/orders/${order.id}`).set(ALEX)).status).toBe(200);
    expect((await request(app).get(`/api/orders/${order.id}`).set(OTHER_CLIENT)).status).toBe(403);
    expect((await request(app).get(`/api/orders/${order.id}`).set(KARIM)).status).toBe(403);
    expect((await request(app).get(`/api/orders/${order.id}`).set(RESTO)).status).toBe(200);

    // ?userId= d'un autre client : toujours limité à ses propres commandes.
    expect((await request(app).get('/api/orders').set(OTHER_CLIENT).query({ userId: 'u-client-1' })).body).toEqual([]);
    expect((await request(app).get('/api/orders').set(ALEX)).body.map((o) => o.id)).toEqual([order.id]);
    expect((await request(app).get('/api/orders').set(RESTO).query({ restaurantId: 'rest_demo' })).body).toHaveLength(1);
    expect((await request(app).get('/api/orders').set(KARIM)).body).toEqual([]);
    expect((await request(app).get('/api/orders').set(ADMIN)).body).toHaveLength(1);
    expect((await request(app).get('/api/orders').set(ADMIN).query({ status: 'flying' })).status).toBe(422);
  });

  test('machine d’états et droits : restaurateur jusqu’à « Prête », admin au-delà', async () => {
    const order = (await placeOrder(app)).body;
    expect((await setStatus(order.id, 'accepted', ALEX)).status).toBe(403);
    expect((await setStatus(order.id, 'ready', RESTO)).status).toBe(409);
    expect((await setStatus(order.id, 'teleported', RESTO)).status).toBe(422);

    const accepted = await setStatus(order.id, 'accepted', RESTO, 'On s’en occupe');
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('accepted');
    expect(accepted.body.history.at(-1)).toMatchObject({ status: 'accepted', note: 'On s’en occupe' });
    // Acceptée : une course est proposée aux livreurs.
    const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.id })).body;
    expect(delivery).toMatchObject({ status: 'waiting', orderReference: order.reference, pickupName: 'SuperBurger Demo' });
    // Même statut renvoyé : sans effet, pas de deuxième course.
    expect((await setStatus(order.id, 'accepted', RESTO)).status).toBe(200);
    expect((await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.id })).body).toHaveLength(1);

    expect((await setStatus(order.id, 'preparing', RESTO)).body.status).toBe('preparing');
    expect((await setStatus(order.id, 'ready', RESTO)).body.status).toBe('ready');
    expect((await setStatus(order.id, 'delivering', RESTO)).status).toBe(403);
    // Le livreur non assigné n'a pas accès à la commande.
    expect((await setStatus(order.id, 'delivering', KARIM)).status).toBe(403);

    const timeline = await request(app).get(`/api/orders/${order.id}/timeline`).set(ALEX);
    expect(timeline.body.map((e) => e.status)).toEqual(['pending', 'accepted', 'preparing', 'ready']);
  });

  test('livrée par l’admin : course terminée, livreur crédité, espèces encaissées', async () => {
    const order = (await placeOrder(app, { paymentMethod: 'cash' })).body;
    await setStatus(order.id, 'accepted', RESTO);
    const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.id })).body;
    await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
    const before = (await request(app).get('/api/couriers/c-1').set(ADMIN)).body;
    expect(before.status).toBe('busy');

    for (const status of ['preparing', 'ready', 'delivering', 'delivered']) {
      expect((await setStatus(order.id, status)).status).toBe(200);
    }
    const done = (await request(app).get(`/api/orders/${order.id}`).set(ALEX)).body;
    expect(done).toMatchObject({ status: 'delivered', paymentStatus: 'paid', courierId: 'c-1' });
    const course = (await request(app).get(`/api/deliveries/${delivery.id}`).set(ADMIN)).body;
    expect(course.status).toBe('delivered');
    const after = (await request(app).get('/api/couriers/c-1').set(ADMIN)).body;
    expect(after.status).toBe('available');
    expect(after.completedDeliveries).toBe(before.completedDeliveries + 1);
    expect(after.totalEarnings).toBeCloseTo(before.totalEarnings + course.earnings, 2);
  });

  test('annulation : client tant que « Nouvelle », restaurateur ensuite ; livreur libéré', async () => {
    const first = (await placeOrder(app)).body;
    const byClient = await request(app).patch(`/api/orders/${first.id}/cancel`).set(ALEX).send({ reason: 'Erreur' });
    expect(byClient.status).toBe(200);
    expect(byClient.body).toMatchObject({ status: 'cancelled', cancelReason: 'Erreur' });

    const second = (await placeOrder(app)).body;
    await setStatus(second.id, 'accepted', RESTO);
    const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: second.id })).body;
    await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });

    const late = await request(app).patch(`/api/orders/${second.id}/cancel`).set(ALEX).send({ reason: 'Trop long' });
    expect(late.status).toBe(409);
    expect(late.body.error).toBe('La commande est déjà en préparation : contactez le restaurant.');
    expect((await request(app).patch(`/api/orders/${second.id}/cancel`).set(KARIM).send({})).status).toBe(403);

    const byResto = await request(app).patch(`/api/orders/${second.id}/cancel`).set(RESTO).send({ reason: 'Produit indisponible' });
    expect(byResto.body.status).toBe('cancelled');
    expect((await request(app).get(`/api/deliveries/${delivery.id}`).set(ADMIN)).body.status).toBe('cancelled');
    expect((await request(app).get('/api/couriers/c-1').set(ADMIN)).body.status).toBe('available');
    // Statut « cancelled » via PATCH /status : mêmes règles.
    expect((await setStatus(second.id, 'preparing', RESTO)).status).toBe(409);
  });

  test('remboursement : admin, commande encaissée (livrée) ; rien à rembourser sinon', async () => {
    // Livrée : les espèces ont été encaissées.
    const paid = (await placeOrder(app)).body;
    expect((await request(app).patch(`/api/orders/${paid.id}/refund`).set(ADMIN)).status).toBe(409);
    for (const status of ['accepted', 'preparing', 'ready', 'delivering', 'delivered']) {
      await setStatus(paid.id, status);
    }
    expect((await request(app).patch(`/api/orders/${paid.id}/refund`).set(ALEX)).status).toBe(403);
    expect((await request(app).patch(`/api/orders/${paid.id}/refund`).set(RESTO)).status).toBe(403);
    const refunded = await request(app).patch(`/api/orders/${paid.id}/refund`).set(ADMIN);
    expect(refunded.status).toBe(200);
    expect(refunded.body).toMatchObject({ status: 'refunded', paymentStatus: 'refunded' });

    // Annulée avant la livraison : rien n'a été encaissé.
    const cash = (await placeOrder(app)).body;
    await request(app).patch(`/api/orders/${cash.id}/cancel`).set(ALEX).send({});
    const nothing = await request(app).patch(`/api/orders/${cash.id}/refund`).set(ADMIN);
    expect(nothing.status).toBe(409);
    expect(nothing.body.error).toBe('Aucun paiement à rembourser pour cette commande.');
  });

  test('PUT (note), suppression admin et statistiques par rôle', async () => {
    const order = (await placeOrder(app)).body;
    const edited = await request(app).put(`/api/orders/${order.id}`).set(RESTO).send({ ...order, note: 'Allergie arachide', totalAmount: 1 });
    expect(edited.status).toBe(200);
    expect(edited.body.note).toBe('Allergie arachide');
    expect(edited.body.totalAmount).toBe(order.totalAmount);
    expect((await request(app).put(`/api/orders/${order.id}`).set(ALEX).send({ note: 'x' })).status).toBe(403);

    const other = (await placeOrder(app)).body;
    await request(app).patch(`/api/orders/${other.id}/cancel`).set(ALEX).send({});
    const stats = (await request(app).get('/api/orders/stats').set(RESTO)).body;
    expect(stats.totalOrders).toBe(2);
    expect(stats.byStatus).toMatchObject({ pending: 1, cancelled: 1 });
    expect(stats.totalRevenue).toBe(order.totalAmount);
    expect((await request(app).get('/api/orders/stats').set(ALEX)).status).toBe(403);

    expect((await request(app).delete(`/api/orders/${order.id}`).set(RESTO)).status).toBe(403);
    expect((await request(app).delete(`/api/orders/${order.id}`).set(ADMIN)).status).toBe(200);
    expect((await request(app).get(`/api/orders/${order.id}`).set(ADMIN)).status).toBe(404);
  });
});
