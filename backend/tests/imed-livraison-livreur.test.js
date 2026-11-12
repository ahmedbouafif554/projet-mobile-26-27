'use strict';

const request = require('supertest');
const app = require('../src/app');
const helpers = require('./helpers');
const { init, reset, close, query } = require('../src/data/db');

// Jetons acceptés par le middleware, comme ceux posés par le front.
const ADMIN = { Authorization: 'Bearer mock-token-u-admin' };
const KARIM = { Authorization: 'Bearer mock-token-u-courier-1' }; // livreur c-1 (validé)
const ALEX = { Authorization: 'Bearer mock-token-u-client-1' };
const RESTO = { Authorization: 'Bearer mock-token-u-resto-1' };

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
});

afterAll(async () => {
  await close();
});

/** Commande d'Alex acceptée par le restaurant : sa course « à assigner » existe. */
async function placeOrder() {
  const { order, delivery } = await helpers.acceptedOrder(app, {
    items: [{ product: { id: 'prod_1' }, quantity: 2 }],
  });
  expect(delivery).toBeDefined();
  return { order, delivery };
}

async function courier(id) {
  return (await request(app).get(`/api/couriers/${id}`).set(ADMIN)).body;
}

describe('Livreurs — /api/couriers', () => {
  test('liste au format Courier.toJson avec statut des justificatifs et filtres', async () => {
    expect((await request(app).get('/api/couriers')).status).toBe(401);
    expect((await request(app).get('/api/couriers').set(ALEX)).status).toBe(403);
    // Un livreur ne voit que son propre profil.
    const own = await request(app).get('/api/couriers').set(KARIM);
    expect(own.body.map((c) => c.id)).toEqual(['c-1']);
    expect((await request(app).get('/api/couriers').set(KARIM).query({ userId: 'u-courier-6' })).body).toEqual([]);
    expect((await request(app).get('/api/couriers/c-6').set(KARIM)).status).toBe(403);

    const res = await request(app).get('/api/couriers').set(ADMIN);
    expect(res.status).toBe(200);
    const karim = res.body.find((c) => c.id === 'c-1');
    expect(karim).toMatchObject({
      userId: 'u-courier-1',
      firstName: 'Karim',
      vehicle: 'scooter',
      status: 'available',
      documentStatus: 'approved',
    });
    expect(karim.documents).toHaveLength(3);

    const pending = await request(app).get('/api/couriers').set(ADMIN).query({ documentStatus: 'pending' });
    expect(pending.body.map((c) => c.id)).toEqual(['c-6']);
    const byUser = await request(app).get('/api/couriers').set(ADMIN).query({ userId: 'u-courier-1' });
    expect(byUser.body).toHaveLength(1);
  });

  test('profil du livreur connecté (GET /couriers/me)', async () => {
    const me = await request(app).get('/api/couriers/me').set(KARIM);
    expect(me.status).toBe(200);
    expect(me.body.id).toBe('c-1');
    const noToken = await request(app).get('/api/couriers/me');
    expect(noToken.status).toBe(401);
  });

  test('en ligne / hors ligne : justificatifs validés obligatoires, impossible pendant une course', async () => {
    const offline = await request(app).patch('/api/couriers/c-1/status').set(KARIM).send({ status: 'offline' });
    expect(offline.status).toBe(200);
    expect(offline.body.status).toBe('offline');

    // Mehdi (c-6) a des justificatifs à vérifier : l'admin ne peut pas le mettre en ligne.
    const mehdi = await request(app).patch('/api/couriers/c-6/status').set(ADMIN).send({ status: 'available' });
    expect(mehdi.status).toBe(422);

    // Un livreur ne modifie pas le statut d'un autre.
    const other = await request(app).patch('/api/couriers/c-6/status').set(KARIM).send({ status: 'offline' });
    expect(other.status).toBe(403);

    // « En livraison » ne se pose pas à la main.
    const busy = await request(app).patch('/api/couriers/c-1/status').set(KARIM).send({ status: 'busy' });
    expect(busy.status).toBe(422);
  });

  test('PUT complet : le livreur ne peut pas se valider lui-même ; un renvoi repasse à vérifier', async () => {
    const mehdi = await courier('c-6');
    await query("UPDATE users SET status = 'active' WHERE id = 'u-courier-6'");
    // Mehdi n'est pas validé : le middleware refuse sa session.
    const selfApprove = await request(app)
      .put('/api/couriers/c-6')
      .set({ Authorization: 'Bearer mock-token-u-courier-6' })
      .send({ ...mehdi, documents: mehdi.documents.map((d) => ({ ...d, status: 'approved' })) });
    expect(selfApprove.status).toBe(403);
    expect((await courier('c-6')).documentStatus).toBe('pending');

    // Karim change de véhicule : ses justificatifs validés restent validés,
    // ses statistiques ne sont pas modifiables.
    const karim = await courier('c-1');
    const saved = await request(app)
      .put('/api/couriers/c-1')
      .set(KARIM)
      .send({ ...karim, vehicle: 'bike', plateNumber: 'AA-000-AA', completedDeliveries: 9999, totalEarnings: 1e6 });
    expect(saved.status).toBe(200);
    expect(saved.body.vehicle).toBe('bike');
    expect(saved.body.plateNumber).toBeNull();
    expect(saved.body.completedDeliveries).toBe(karim.completedDeliveries);
    expect(saved.body.totalEarnings).toBe(karim.totalEarnings);
    expect(saved.body.documentStatus).toBe('approved');

    // Renvoi du permis (MyCourierController.resubmit) : à vérifier, et hors ligne.
    const resubmit = await request(app)
      .put('/api/couriers/c-1')
      .set(KARIM)
      .send({
        ...saved.body,
        documents: saved.body.documents.map((d) =>
          d.type === 'license' ? { type: 'license', status: 'pending', uploadedAt: new Date().toISOString() } : d,
        ),
      });
    expect(resubmit.status).toBe(200);
    expect(resubmit.body.documents.find((d) => d.type === 'license').status).toBe('pending');
    expect(resubmit.body.documentStatus).toBe('pending');
    expect(resubmit.body.status).toBe('offline');
  });

  test('admin : validation des justificatifs (tous ou un seul) et suppression', async () => {
    const one = await request(app).patch('/api/couriers/c-6/documents').set(ADMIN).send({ status: 'approved', type: 'idCard' });
    expect(one.status).toBe(200);
    expect(one.body.documents.find((d) => d.type === 'idCard').status).toBe('approved');
    expect(one.body.documentStatus).toBe('pending');

    const all = await request(app).patch('/api/couriers/c-6/documents').set(ADMIN).send({ status: 'approved' });
    expect(all.body.documentStatus).toBe('approved');

    const notAdmin = await request(app).patch('/api/couriers/c-6/documents').set(KARIM).send({ status: 'rejected' });
    expect(notAdmin.status).toBe(403);

    const removed = await request(app).delete('/api/couriers/c-6').set(ADMIN);
    expect(removed.status).toBe(204);
    expect((await request(app).get('/api/couriers/c-6').set(ADMIN)).status).toBe(404);
  });

  test('création de profil : jamais anonyme, jamais par un autre rôle', async () => {
    expect((await request(app).post('/api/users').send({ firstName: 'Lina', role: 'courier' })).status).toBe(401);
    expect((await request(app).post('/api/couriers').send({ userId: 'u-courier-6' })).status).toBe(401);
    expect((await request(app).post('/api/couriers').set(ALEX).send({ userId: 'u-client-1' })).status).toBe(403);

    // L'admin crée le compte puis le profil (formulaire du back office).
    const user = await request(app).post('/api/users').set(ADMIN).send({
      id: '',
      firstName: 'Lina',
      lastName: 'Haddad',
      email: 'lina.haddad@exemple.fr',
      phone: '0700000001',
      role: 'courier',
      status: 'active',
      createdAt: new Date().toISOString(),
    });
    expect(user.status).toBe(201);
    // En ligne sans justificatifs validés : refusé, même pour l'admin.
    const notApproved = await request(app).post('/api/couriers').set(ADMIN).send({
      userId: user.body.id,
      vehicle: 'car',
      status: 'available',
    });
    expect(notApproved.status).toBe(422);
    const created = await request(app).post('/api/couriers').set(ADMIN).send({
      userId: user.body.id,
      vehicle: 'car',
      status: 'offline',
    });
    expect(created.status).toBe(201);
    expect(created.body.status).toBe('offline');
    expect(created.body.documentStatus).toBe('pending');
  });

  test('position GPS, livreurs proches et synthèse admin', async () => {
    const moved = await request(app).post('/api/couriers/c-1/location').set(KARIM).send({ latitude: 48.87, longitude: 2.33 });
    expect(moved.status).toBe(200);
    expect((await courier('c-1')).latitude).toBe(48.87);

    const bad = await request(app).post('/api/couriers/c-1/location').set(KARIM).send({ latitude: 200, longitude: 2 });
    expect(bad.status).toBe(422);

    const history = await request(app).get('/api/couriers/c-1/locations').set(KARIM);
    expect(history.body.at(-1)).toMatchObject({ latitude: 48.87, longitude: 2.33 });

    const nearby = await request(app).get('/api/couriers/nearby').set(ADMIN).query({ latitude: 48.8699, longitude: 2.3305 });
    expect(nearby.body.map((n) => n.courier.id)).toEqual(['c-1']);

    const overview = await request(app).get('/api/couriers/overview').set(ADMIN);
    expect(overview.body.total).toBe(2);
    expect(overview.body.documentsPending).toBe(1);
  });
});

describe('Livraisons — /api/deliveries', () => {
  test('récupération impossible tant que le restaurant n’a pas accepté la commande', async () => {
    const order = (await helpers.placeOrder(app, { items: [{ product: { id: 'prod_1' }, quantity: 1 }] })).body;
    const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.id })).body;
    expect(delivery.status).toBe('waiting');
    expect(delivery.orderStatus).toBe('pending');

    expect((await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' })).status).toBe(200);
    const early = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'pickedUp' });
    expect(early.status).toBe(409);
    expect(early.body.error).toMatch(/pas encore accepté la commande/);

    const ok = await request(app).patch(`/api/orders/${order.id}/status`).set(ADMIN).send({ status: 'accepted' });
    expect(ok.status).toBe(200);
    const picked = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'pickedUp' });
    expect(picked.status).toBe(200);
    expect((await request(app).get(`/api/orders/${order.id}`).set(ADMIN)).body.status).toBe('delivering');
  });

  test('cycle complet côté livreur : accepter, récupérer, en route, livrer', async () => {
    const { order, delivery } = await placeOrder();
    expect(delivery.status).toBe('waiting');
    expect(delivery.orderReference).toBe(order.reference);
    expect(delivery.pickupName).toBe('SuperBurger Demo');
    expect(delivery.customerName).toBe('Alex Martin');

    // Courses proposées : le livreur ne voit pas le code de remise.
    const available = await request(app).get('/api/deliveries').set(KARIM).query({ status: 'waiting' });
    const offer = available.body.find((d) => d.id === delivery.id);
    expect(offer).toBeDefined();
    expect(offer.otpCode).toBeUndefined();

    const before = await courier('c-1');
    const accepted = await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('assigned');
    expect(accepted.body.assignedAt).toEqual(expect.any(String));
    expect((await courier('c-1')).status).toBe('busy');

    // Comme le front : setStatus(busy) juste après → sans effet.
    expect((await request(app).patch('/api/couriers/c-1/status').set(KARIM).send({ status: 'busy' })).status).toBe(200);
    // Pas de déconnexion pendant la course.
    const offline = await request(app).patch('/api/couriers/c-1/status').set(KARIM).send({ status: 'offline' });
    expect(offline.status).toBe(409);
    expect(offline.body.error).toBe('Terminez votre course avant de vous déconnecter.');

    // Commande acceptée par le restaurant : la remise au livreur vaut
    // « prête », même si le restaurant n'a pas appuyé sur « Prête ».
    const picked = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'pickedUp' });
    expect(picked.body.status).toBe('pickedUp');
    expect(picked.body.pickedUpAt).toEqual(expect.any(String));
    expect((await request(app).get(`/api/orders/${order.id}`).set(ALEX)).body.status).toBe('delivering');
    // Le livreur voit la commande qu'il livre ; l'appel redondant du front est sans effet.
    const sameStatus = await request(app).patch(`/api/orders/${order.id}/status`).set(KARIM).send({ status: 'delivering' });
    expect(sameStatus.status).toBe(200);

    const transit = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'inTransit' });
    expect(transit.body.status).toBe('inTransit');

    const done = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'delivered' });
    expect(done.status).toBe(200);
    expect(done.body.status).toBe('delivered');
    expect(done.body.deliveredAt).toEqual(expect.any(String));
    expect((await request(app).get(`/api/orders/${order.id}`).set(ALEX)).body.status).toBe('delivered');

    const after = await courier('c-1');
    expect(after.status).toBe('available');
    expect(after.completedDeliveries).toBe(before.completedDeliveries + 1);
    expect(after.totalEarnings).toBeCloseTo(before.totalEarnings + done.body.fee + done.body.tip, 2);

    // Le front renvoie ensuite le profil avec +1 course : pas de double comptage.
    const frontPut = await request(app)
      .put('/api/couriers/c-1')
      .set(KARIM)
      .send({ ...after, status: 'available', completedDeliveries: after.completedDeliveries + 1 });
    expect(frontPut.body.completedDeliveries).toBe(after.completedDeliveries);

    // Gains du jour et des 7 derniers jours.
    const stats = await request(app).get('/api/couriers/c-1/stats').set(KARIM);
    expect(stats.body.todayDeliveries).toBe(1);
    expect(stats.body.todayEarnings).toBeCloseTo(done.body.earnings, 2);
    expect(stats.body.earningsByDay).toHaveLength(7);
    expect(stats.body.earningsByDay[6].total).toBeCloseTo(done.body.earnings, 2);

    const history = await request(app).get(`/api/deliveries/${delivery.id}/history`).set(ADMIN);
    expect(history.body.map((e) => e.status)).toEqual(['waiting', 'assigned', 'pickedUp', 'inTransit', 'delivered']);

    // Course terminée : plus de retour en arrière.
    const back = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(ADMIN).send({ status: 'inTransit' });
    expect(back.status).toBe(400);
  });

  test('règles d’assignation : livreur validé, en ligne, une seule course', async () => {
    const first = await placeOrder();
    const second = await placeOrder();

    // Mehdi : justificatifs non validés.
    const mehdi = await request(app).patch(`/api/deliveries/${first.delivery.id}/assign`).set(ADMIN).send({ courierId: 'c-6' });
    expect(mehdi.status).toBe(422);

    // Karim hors ligne ne peut pas accepter.
    await request(app).patch('/api/couriers/c-1/status').set(KARIM).send({ status: 'offline' });
    const offline = await request(app).patch(`/api/deliveries/${first.delivery.id}/assign`).set(KARIM).send({});
    expect(offline.status).toBe(409);
    expect(offline.body.error).toBe('Passez en ligne pour accepter des courses.');
    await request(app).patch('/api/couriers/c-1/status').set(KARIM).send({ status: 'available' });

    expect((await request(app).post(`/api/deliveries/${first.delivery.id}/accept`).set(KARIM)).status).toBe(200);
    const again = await request(app).patch(`/api/deliveries/${second.delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
    expect(again.status).toBe(409);
    expect(again.body.error).toBe('Vous avez déjà une course en cours.');

    // Un livreur n'accepte pas une course pour un autre.
    const forOther = await request(app).patch(`/api/deliveries/${second.delivery.id}/assign`).set(KARIM).send({ courierId: 'c-6' });
    expect(forOther.status).toBe(403);

    // Un client ne peut pas assigner.
    const client = await request(app).patch(`/api/deliveries/${second.delivery.id}/assign`).set(ALEX).send({ courierId: 'c-1' });
    expect(client.status).toBe(403);
  });

  test('admin : remise à assigner, annulation (livreur libéré) et nouvelle course', async () => {
    const { order, delivery } = await placeOrder();
    await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(ADMIN).send({ courierId: 'c-1' });

    const unassigned = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(ADMIN).send({ status: 'waiting' });
    expect(unassigned.body.status).toBe('waiting');
    expect(unassigned.body.courierId).toBeNull();
    expect((await courier('c-1')).status).toBe('available');

    await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(ADMIN).send({ courierId: 'c-1' });
    // Le livreur ne peut pas annuler lui-même.
    const courierCancel = await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'cancelled' });
    expect(courierCancel.status).toBe(403);

    const cancelled = await request(app)
      .patch(`/api/deliveries/${delivery.id}/status`)
      .set(ADMIN)
      .send({ status: 'cancelled', reason: 'Client injoignable' });
    expect(cancelled.body.status).toBe('cancelled');
    expect(cancelled.body.cancelReason).toBe('Client injoignable');
    expect((await courier('c-1')).status).toBe('available');

    // POST /deliveries (OrdersController._ensureDelivery) : nouvelle course.
    const recreated = await request(app).post('/api/deliveries').set(ADMIN).send({ orderId: order.id, fee: 6 });
    expect(recreated.status).toBe(201);
    expect(recreated.body.status).toBe('waiting');
    expect(recreated.body.fee).toBe(6);
    // Idempotent tant qu'une course non annulée existe.
    const same = await request(app).post('/api/deliveries').set(ADMIN).send({ orderId: order.id });
    expect(same.status).toBe(200);
    expect(same.body.id).toBe(recreated.body.id);
    // Un restaurant ne crée de course que pour ses propres commandes.
    const otherResto = await request(app).post('/api/deliveries').set(RESTO).send({ orderId: order.id });
    expect(otherResto.status).toBe(403);

    // PUT complet (Delivery.toJson) : pourboire modifié.
    const edited = await request(app).put(`/api/deliveries/${recreated.body.id}`).set(ADMIN).send({ ...recreated.body, tip: 2 });
    expect(edited.body.tip).toBe(2);
    expect(edited.body.earnings).toBe(8);

    expect((await request(app).delete(`/api/deliveries/${recreated.body.id}`).set(KARIM)).status).toBe(403);
    expect((await request(app).delete(`/api/deliveries/${recreated.body.id}`).set(ADMIN)).status).toBe(204);
    expect((await request(app).get(`/api/deliveries/${recreated.body.id}`).set(ADMIN)).status).toBe(404);
  });

  test('refus d’une course, courses disponibles, livreur occupé non supprimable', async () => {
    const a = await placeOrder();
    const b = await placeOrder();
    const declined = await request(app).post(`/api/deliveries/${a.delivery.id}/decline`).set(KARIM);
    expect(declined.status).toBe(200);
    const available = await request(app).get('/api/deliveries/available').set(KARIM);
    const ids = available.body.map((d) => d.id);
    expect(ids).not.toContain(a.delivery.id);
    expect(ids).toContain(b.delivery.id);

    await request(app).patch(`/api/deliveries/${b.delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
    expect((await request(app).delete('/api/couriers/c-1').set(ADMIN)).status).toBe(409);

    // Pendant la course, la position est reportée sur la livraison.
    const ping = await request(app).post('/api/couriers/c-1/location').set(KARIM).send({ latitude: 48.869, longitude: 2.331 });
    expect(ping.body.deliveryId).toBe(b.delivery.id);
    expect(ping.body.target).toBe('pickup');
    const tracking = await request(app).get(`/api/deliveries/${b.delivery.id}/tracking`).set(ALEX);
    expect(tracking.status).toBe(200);
    expect(tracking.body.positions.courier).toEqual({ latitude: 48.869, longitude: 2.331 });
    expect(tracking.body.steps).toHaveLength(5);
  });

  test('droits de lecture et code de remise', async () => {
    const { delivery } = await placeOrder();
    expect((await request(app).get(`/api/deliveries/${delivery.id}`)).status).toBe(401);
    // Seuls livreurs et admin voient les courses à accepter.
    expect((await request(app).get('/api/deliveries/available').set(ALEX)).status).toBe(403);
    const own = await request(app).get(`/api/deliveries/${delivery.id}`).set(ALEX);
    expect(own.status).toBe(200);
    expect(own.body.otpCode).toHaveLength(4);

    await query("UPDATE users SET status = 'active' WHERE id = 'u-client-9'");
    const stranger = await request(app).get(`/api/deliveries/${delivery.id}`).set({ Authorization: 'Bearer mock-token-u-client-9' });
    expect(stranger.status).toBe(403);

    const mine = await request(app).get('/api/deliveries').set(KARIM).query({ courierId: 'c-6' });
    expect(mine.status).toBe(403);

    const badStatus = await request(app).get('/api/deliveries').set(ADMIN).query({ status: 'flying' });
    expect(badStatus.status).toBe(422);

    const stats = await request(app).get('/api/deliveries/stats').set(ADMIN);
    expect(stats.body.byStatus.waiting).toBeGreaterThanOrEqual(1);
  });
});
