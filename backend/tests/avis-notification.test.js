'use strict';

const request = require('supertest');
const app = require('../src/app');
const helpers = require('./helpers');
const { init, reset, close } = require('../src/data/db');
const avisNotification = require('../src/avis_notification');

const ADMIN = { Authorization: 'Bearer mock-token-u-admin' };
const ALEX = { Authorization: 'Bearer mock-token-u-client-1' };
const KARIM = { Authorization: 'Bearer mock-token-u-courier-1' };
const RESTO = { Authorization: 'Bearer mock-token-u-resto-1' };

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  await avisNotification.clear();
});

afterAll(async () => {
  await close();
});

/** Commande d'Alex livrée (via le module livraison). */
async function deliveredOrder() {
  return helpers.deliveredOrder(app);
}

function reviewJson(orderId, extra = {}) {
  return {
    id: '',
    restaurantId: 'rest_demo',
    userId: 'u-client-1',
    userName: 'Alex M.',
    orderId,
    rating: 4,
    foodRating: 5,
    deliveryRating: 4,
    packagingRating: null,
    comment: 'Très bon burger',
    photos: [],
    status: 'pending',
    reply: null,
    helpfulCount: 0,
    reportCount: 0,
    createdAt: new Date().toISOString(),
    ...extra,
  };
}

async function approvedReview() {
  const order = await deliveredOrder();
  const created = await request(app).post('/api/reviews').set(ALEX).send(reviewJson(order.id));
  await request(app).patch(`/api/reviews/${created.body.id}/status`).set(ADMIN).send({ status: 'approved' });
  return (await request(app).get(`/api/reviews/${created.body.id}`)).body;
}

describe('Avis — /api/reviews', () => {
  test('création : client, commande livrée, une seule fois, en modération', async () => {
    const pending = await helpers.placeOrder(app);
    expect((await request(app).post('/api/reviews').set(ALEX).send(reviewJson(pending.body.id))).status).toBe(422);

    const order = await deliveredOrder();
    expect((await request(app).post('/api/reviews').set(KARIM).send(reviewJson(order.id))).status).toBe(403);
    expect((await request(app).post('/api/reviews').send(reviewJson(order.id))).status).toBe(401);
    expect((await request(app).post('/api/reviews').set(ALEX).send(reviewJson(order.id, { rating: 9 }))).status).toBe(422);

    const created = await request(app)
      .post('/api/reviews')
      .set(ALEX)
      .send(reviewJson(order.id, { status: 'approved', helpfulCount: 99 }));
    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({ status: 'pending', helpfulCount: 0, restaurantId: 'rest_demo', orderId: order.id });

    expect((await request(app).post('/api/reviews').set(ALEX).send(reviewJson(order.id))).status).toBe(409);

    // Non publié : invisible du public, visible de l'auteur.
    const pub = await request(app).get('/api/restaurants/rest_demo/reviews').query({ status: 'approved' });
    expect(pub.body).toHaveLength(0);
    expect((await request(app).get(`/api/reviews/${created.body.id}`)).status).toBe(404);
    const mine = await request(app).get('/api/reviews').set(ALEX);
    expect(mine.body.map((r) => r.id)).toContain(created.body.id);
  });

  test('modération par l’admin, note du restaurant et notifications', async () => {
    const order = await deliveredOrder();
    const created = await request(app).post('/api/reviews').set(ALEX).send(reviewJson(order.id));
    expect((await request(app).patch(`/api/reviews/${created.body.id}/status`).set(ALEX).send({ status: 'approved' })).status).toBe(403);

    const approved = await request(app).patch(`/api/reviews/${created.body.id}/status`).set(ADMIN).send({ status: 'approved' });
    expect(approved.body.status).toBe('approved');

    const restaurant = await request(app).get('/api/restaurants/rest_demo');
    expect(restaurant.body.rating).toBe(4);
    expect(restaurant.body.reviewCount).toBe(1);

    const pub = await request(app).get('/api/restaurants/rest_demo/reviews').query({ status: 'approved' });
    expect(pub.body.map((r) => r.id)).toEqual([created.body.id]);

    const notes = await request(app).get('/api/users/u-client-1/notifications').set(ALEX);
    expect(notes.body.some((n) => n.type === 'review' && n.title.includes('publié'))).toBe(true);
  });

  test('réponse : admin ou restaurateur du restaurant, sur un avis publié', async () => {
    const review = await approvedReview();
    expect((await request(app).patch(`/api/reviews/${review.id}/reply`).set(RESTO).send({ text: 'Merci' })).status).toBe(403);
    const replied = await request(app)
      .patch(`/api/reviews/${review.id}/reply`)
      .set(ADMIN)
      .send({ text: ' Merci pour votre retour ', authorName: 'Quelqu’un', at: new Date().toISOString() });
    expect(replied.body.reply).toMatchObject({ text: 'Merci pour votre retour', authorName: 'Équipe SuperFaster' });
    expect((await request(app).patch(`/api/reviews/${review.id}/reply`).set(ADMIN).send({ text: '  ' })).status).toBe(422);
    const removed = await request(app).delete(`/api/reviews/${review.id}/reply`).set(ADMIN);
    expect(removed.body.reply).toBeNull();
  });

  test('« Utile » via PUT (une voix par personne), signalement, modification par l’auteur', async () => {
    const review = await approvedReview();
    const voted = await request(app).put(`/api/reviews/${review.id}`).set(KARIM).send({ ...review, helpfulCount: 1 });
    expect(voted.body.helpfulCount).toBe(1);
    const again = await request(app).put(`/api/reviews/${review.id}`).set(KARIM).send({ ...voted.body, helpfulCount: 2 });
    expect(again.body.helpfulCount).toBe(1);
    expect((await request(app).put(`/api/reviews/${review.id}`).set(KARIM).send({ ...review, comment: 'piraté' })).status).toBe(403);

    const reported = await request(app).post(`/api/reviews/${review.id}/report`).set(KARIM).send({ reason: 'spam' });
    expect(reported.body.reportCount).toBe(1);
    const reports = await request(app).get(`/api/reviews/${review.id}/reports`).set(ADMIN);
    expect(reports.body[0].reason).toBe('spam');

    const edited = await request(app).put(`/api/reviews/${review.id}`).set(ALEX).send({ ...review, rating: 5, comment: 'Encore mieux' });
    expect(edited.body).toMatchObject({ status: 'pending', rating: 5, comment: 'Encore mieux' });
    expect((await request(app).get('/api/restaurants/rest_demo')).body.reviewCount).toBe(0);

    const stats = await request(app).get('/api/reviews/stats').set(ADMIN).query({ restaurantId: 'rest_demo' });
    expect(stats.body.byStatus.pending).toBe(1);

    expect((await request(app).delete(`/api/reviews/${review.id}`).set(ALEX)).status).toBe(204);
  });

  test('le restaurateur voit les avis de son restaurant', async () => {
    const review = await approvedReview();
    // u-resto-1 gère r1 : il ne voit que les avis publiés de rest_demo.
    const list = await request(app).get('/api/restaurants/rest_demo/reviews').set(RESTO);
    expect(list.body.map((r) => r.id)).toEqual([review.id]);
    expect((await request(app).get('/api/restaurants/rest_demo')).status).toBe(200);
  });
});

describe('Notifications — /api/notifications et /api/users/:id/notifications', () => {
  test('créer, lire, supprimer puis restaurer (même id)', async () => {
    const now = new Date().toISOString();
    const created = await request(app).post('/api/notifications').set(ALEX).send({
      id: '', userId: 'u-client-1', title: 'Commande confirmée', body: 'ok', type: 'order',
      isRead: false, route: '/orders/1', imageUrl: null, createdAt: now,
    });
    expect(created.status).toBe(201);
    expect((await request(app).post('/api/notifications').set(ALEX).send({ userId: 'u-client-9', title: 'x' })).status).toBe(403);
    expect((await request(app).post('/api/notifications').set(ALEX).send({ title: 'x', route: 'http://evil' })).status).toBe(422);

    const read = await request(app).patch(`/api/notifications/${created.body.id}/read`).set(ALEX);
    expect(read.body.isRead).toBe(true);
    expect((await request(app).get(`/api/notifications/${created.body.id}`).set(KARIM)).status).toBe(404);

    expect((await request(app).delete(`/api/notifications/${created.body.id}`).set(ALEX)).status).toBe(204);
    const restored = await request(app).post('/api/notifications').set(ALEX).send(read.body);
    expect(restored.body).toMatchObject({ id: created.body.id, createdAt: created.body.createdAt, isRead: true });

    expect((await request(app).get('/api/users/u-client-1/notifications').set(KARIM)).status).toBe(403);
  });

  test('préférences : catégories désactivées masquées', async () => {
    await request(app).post('/api/notifications').set(ALEX).send({ title: 'Promo', type: 'promo' });
    await request(app).post('/api/notifications').set(ALEX).send({ title: 'Commande', type: 'order' });
    const saved = await request(app)
      .put('/api/users/u-client-1/notification-settings')
      .set(ALEX)
      .send({ types: { promo: false }, channels: ['push'] });
    expect(saved.body.types).toMatchObject({ promo: false, order: true });
    const list = await request(app).get('/api/users/u-client-1/notifications').set(ALEX);
    expect(list.body.map((n) => n.title)).toEqual(['Commande']);
    expect((await request(app).put('/api/users/u-client-1/notification-settings').set(ALEX).send({ channels: ['fax'] })).status).toBe(422);
  });
});

describe('Campagnes — /api/campaigns', () => {
  test('brouillon, envoi à une audience, lu par destinataire, taux d’ouverture', async () => {
    expect((await request(app).get('/api/campaigns').set(ALEX)).status).toBe(403);
    const draft = await request(app).post('/api/campaigns').set(ADMIN).send({
      id: '', title: 'Promo -20%', body: 'Ce soir', audience: 'clients', status: 'draft', createdAt: new Date().toISOString(),
    });
    expect(draft.status).toBe(201);
    expect(draft.body.status).toBe('draft');
    expect((await request(app).post('/api/campaigns').set(ADMIN).send({
      title: 'x', body: 'y', status: 'scheduled', scheduledAt: '2020-01-01T00:00:00Z',
    })).status).toBe(422);

    const sent = await request(app).patch(`/api/campaigns/${draft.body.id}/send`).set(ADMIN);
    expect(sent.body.status).toBe('sent');
    expect(sent.body.recipientCount).toBeGreaterThan(0);
    expect((await request(app).patch(`/api/campaigns/${draft.body.id}/send`).set(ADMIN)).status).toBe(409);
    expect((await request(app).put(`/api/campaigns/${draft.body.id}`).set(ADMIN).send({ ...sent.body, title: 'z' })).status).toBe(409);

    const alex = await request(app).get('/api/users/u-client-1/notifications').set(ALEX);
    const promo = alex.body.find((n) => n.type === 'promo');
    expect(promo).toMatchObject({ userId: null, isRead: false });
    const karim = await request(app).get('/api/users/u-courier-1/notifications').set(KARIM);
    expect(karim.body.some((n) => n.type === 'promo')).toBe(false);

    const all = await request(app).post('/api/users/u-client-1/notifications/read-all').set(ALEX);
    expect(all.body.unread).toBe(0);
    const stats = await request(app).get(`/api/campaigns/${draft.body.id}`).set(ADMIN);
    expect(stats.body.openedCount).toBe(1);

    // Masquée pour Alex seulement.
    expect((await request(app).delete(`/api/notifications/${promo.id}`).set(ALEX)).status).toBe(204);
    const after = await request(app).get('/api/users/u-client-1/notifications').set(ALEX);
    expect(after.body.some((n) => n.id === promo.id)).toBe(false);
    const admin = await request(app).get('/api/notifications').set(ADMIN);
    expect(admin.body.some((n) => n.id === promo.id)).toBe(true);
  });

  test('campagne programmée envoyée quand son heure est passée', async () => {
    const soon = new Date(Date.now() + 1500).toISOString();
    const scheduled = await request(app).post('/api/campaigns').set(ADMIN).send({
      title: 'Bientôt', body: 'Hop', audience: 'all', status: 'scheduled', scheduledAt: soon,
    });
    expect(scheduled.body.status).toBe('scheduled');
    await new Promise((resolve) => setTimeout(resolve, 1700));
    const list = await request(app).get('/api/users/u-courier-1/notifications').set(KARIM);
    expect(list.body.some((n) => n.title === 'Bientôt')).toBe(true);
    expect((await request(app).get(`/api/campaigns/${scheduled.body.id}`).set(ADMIN)).body.status).toBe('sent');
  });
});
