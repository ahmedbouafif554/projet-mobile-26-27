const request = require('supertest');
const app = require('../src/app');
const { init, reset, close } = require('../src/data/db');

const PASSWORD = 'demo1234';

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
});

afterAll(async () => {
  await close();
});

function auth(token) {
  return { Authorization: `Bearer ${token}` };
}

async function login(email, extra = {}) {
  return request(app)
    .post('/api/auth/login')
    .send({ email, password: PASSWORD, ...extra });
}

describe('inscription', () => {
  test('client : compte créé et session ouverte sans code SMS', async () => {
    const created = await request(app).post('/api/auth/register').send({
      firstName: 'Zoé',
      lastName: 'Martin',
      email: 'zoe.martin@exemple.fr',
      phone: '0611223344',
      password: 'secret12',
      role: 'client',
    });

    expect(created.status).toBe(201);
    expect(created.body.token).toEqual(expect.any(String));
    expect(created.body.user.role).toBe('client');
    expect(created.body.user.status).toBe('active');
    expect(created.body.courier).toBeNull();
    expect(created.body.user.password).toBeUndefined();
  });

  test('livreur : profil créé avec les trois justificatifs à vérifier', async () => {
    const photo = `data:image/png;base64,${'A'.repeat(80)}`;
    const missing = await request(app).post('/api/auth/register').send({
      firstName: 'Sami',
      lastName: 'Kaci',
      email: 'sami.kaci@exemple.fr',
      phone: '0700000000',
      password: 'secret12',
      role: 'courier',
    });
    expect(missing.status).toBe(422);

    const created = await request(app).post('/api/auth/register').send({
      firstName: 'Sami',
      lastName: 'Kaci',
      email: 'sami.kaci@exemple.fr',
      phone: '0700000000',
      password: 'secret12',
      role: 'courier',
      documents: ['idCard', 'license', 'insurance'].map((type) => ({
        type,
        imageData: photo,
      })),
    });

    expect(created.status).toBe(201);
    expect(created.body.token).toBeNull();
    expect(created.body.user.role).toBe('courier');
    const docs = created.body.courier.documents;
    expect(docs.map((doc) => doc.type).sort()).toEqual(['idCard', 'insurance', 'license']);
    expect(docs.every((doc) => doc.status === 'pending')).toBe(true);

    const denied = await login('sami.kaci@exemple.fr', {
      space: 'frontOffice',
      role: 'courier',
      password: 'secret12',
    });
    expect(denied.status).toBe(403);
    expect(denied.body.error).toBe(
      'Votre compte livreur est en attente de validation par un administrateur.',
    );

    const admin = await login('admin@superfaster.fr', { space: 'backOffice' });
    const approved = await request(app)
      .patch(`/api/couriers/${created.body.courier.id}/documents`)
      .set(auth(admin.body.token))
      .send({ status: 'approved' });
    expect(approved.status).toBe(200);

    const accepted = await login('sami.kaci@exemple.fr', {
      space: 'frontOffice',
      role: 'courier',
      password: 'secret12',
    });
    expect(accepted.status).toBe(200);
    expect(accepted.body.user.role).toBe('courier');

    const listed = await request(app).get('/api/couriers').query({ userId: created.body.user.id });
    expect(listed.body).toHaveLength(1);
    expect(listed.body[0].id).toBe(created.body.courier.id);
  });

  test('restaurant et admin ne s’inscrivent pas sur l’application mobile', async () => {
    for (const role of ['restaurant', 'admin']) {
      const res = await request(app).post('/api/auth/register').send({
        firstName: 'Nora',
        lastName: 'Bernard',
        email: `${role}@exemple.fr`,
        phone: '0611223344',
        password: 'secret12',
        role,
      });
      expect(res.status).toBe(403);
      expect(res.body.error).toBe("Ce type de compte s'inscrit dans l'Espace Pro.");
    }
  });

  test('e-mail déjà utilisé et formulaire invalide', async () => {
    const duplicate = await request(app).post('/api/auth/register').send({
      firstName: 'Alex',
      lastName: 'Martin',
      email: 'Alex.Martin@exemple.fr',
      phone: '0611223344',
      password: 'secret12',
    });
    expect(duplicate.status).toBe(409);
    expect(duplicate.body.error).toBe('Un compte existe déjà avec cet e-mail.');

    const invalid = await request(app).post('/api/auth/register').send({
      firstName: 'A',
      lastName: 'Martin',
      email: 'pas-un-email',
      phone: '12',
      password: '123',
      role: 'Livreur',
    });
    expect(invalid.status).toBe(422);
  });
});

describe('connexion et rôles', () => {
  test('client dans l’application mobile', async () => {
    const res = await login('alex.martin@exemple.fr', {
      space: 'frontOffice',
      role: 'client',
    });
    expect(res.status).toBe(200);
    expect(res.body.user.role).toBe('client');
    expect(res.body.user.id).toBe('u-client-1');
    expect(res.body.token).toEqual(expect.any(String));

    const me = await request(app).get('/api/auth/me').set(auth(res.body.token));
    expect(me.body.email).toBe('alex.martin@exemple.fr');
  });

  test('le rôle coché doit correspondre au compte', async () => {
    const mismatch = await login('alex.martin@exemple.fr', {
      space: 'frontOffice',
      role: 'courier',
    });
    expect(mismatch.status).toBe(403);
    expect(mismatch.body.error).toBe(
      'Ce compte est un compte client : sélectionnez « Client ».',
    );

    const courier = await login('karim.benali@superfaster.fr', {
      space: 'frontOffice',
      role: 'courier',
    });
    expect(courier.status).toBe(200);
    expect(courier.body.user.role).toBe('courier');
  });

  test('un client ne peut pas ouvrir l’Espace Pro', async () => {
    const res = await login('alex.martin@exemple.fr', { space: 'backOffice' });
    expect(res.status).toBe(403);
    expect(res.body.error).toBe(
      "L'Espace Pro est réservé aux restaurants et à l'administration.",
    );
  });

  test('e-mail inconnu, mot de passe trop court, compte bloqué, restaurateur en attente', async () => {
    const short = await request(app).post('/api/auth/login').send({
      email: 'inconnu@exemple.fr',
      password: '123',
    });
    expect(short.status).toBe(401);
    expect(short.body.error).toBe('Mot de passe incorrect.');

    const unknown = await request(app).post('/api/auth/login').send({
      email: 'inconnu@exemple.fr',
      password: '123456',
    });
    expect(unknown.status).toBe(401);
    expect(unknown.body.error).toBe('Aucun compte ne correspond à cet e-mail.');

    const wrong = await login('alex.martin@exemple.fr');
    expect(wrong.status).toBe(200);
    const bad = await request(app).post('/api/auth/login').send({
      email: 'alex.martin@exemple.fr',
      password: 'mauvais',
    });
    expect(bad.status).toBe(401);

    const blocked = await login('thomas.bonnet@exemple.fr', { space: 'frontOffice' });
    expect(blocked.status).toBe(403);
    expect(blocked.body.error).toBe('Ce compte est bloqué. Contactez le support.');

    const pending = await login('minh@wokexpress.fr', { space: 'backOffice' });
    expect(pending.status).toBe(403);
    expect(pending.body.error).toBe(
      'Votre inscription est en cours de validation par notre équipe.',
    );
  });

  test('seul un admin change un rôle, et pas le sien', async () => {
    const client = await login('alex.martin@exemple.fr', { space: 'frontOffice' });
    const forbidden = await request(app)
      .patch('/api/users/u-courier-1/role')
      .set(auth(client.body.token))
      .send({ role: 'admin' });
    expect(forbidden.status).toBe(403);

    const admin = await login('admin@superfaster.fr', { space: 'backOffice' });
    const own = await request(app)
      .patch('/api/users/u-admin/role')
      .set(auth(admin.body.token))
      .send({ role: 'client' });
    expect(own.status).toBe(403);
    expect(own.body.error).toBe('Vous ne pouvez pas modifier votre propre rôle.');

    const ownBlock = await request(app)
      .patch('/api/users/u-admin/status')
      .set(auth(admin.body.token))
      .send({ status: 'blocked' });
    expect(ownBlock.status).toBe(403);

    const promoted = await request(app)
      .patch('/api/users/u-client-1/role')
      .set(auth(admin.body.token))
      .send({ role: 'courier' });
    expect(promoted.status).toBe(200);
    expect(promoted.body.role).toBe('courier');

    const profile = await request(app).get('/api/couriers').query({ userId: 'u-client-1' });
    expect(profile.body).toHaveLength(1);
    expect(profile.body[0].documents.every((doc) => doc.status === 'pending')).toBe(true);

    const invalid = await request(app)
      .patch('/api/users/u-client-1/role')
      .set(auth(admin.body.token))
      .send({ role: 'superadmin' });
    expect(invalid.status).toBe(422);
  });
});

describe('contrat utilisé par le frontend, sans modifier les écrans', () => {
  test('POST /users puis POST /couriers, comme AuthService.register', async () => {
    const user = await request(app).post('/api/users').send({
      id: '',
      firstName: 'Sami',
      lastName: 'Kaci',
      email: 'sami.kaci@exemple.fr',
      phone: '0700000000',
      role: 'courier',
      status: 'active',
      avatarUrl: null,
      restaurantId: null,
      loyaltyPoints: 0,
      createdAt: new Date().toISOString(),
      lastLoginAt: null,
    });
    expect(user.status).toBe(201);
    expect(user.body.id).toEqual(expect.any(String));
    expect(user.body.role).toBe('courier');

    const found = await request(app).get('/api/users').query({ email: 'sami.kaci@exemple.fr' });
    expect(found.body).toHaveLength(1);
    expect(found.body[0].id).toBe(user.body.id);

    const now = new Date().toISOString();
    const courier = await request(app).post('/api/couriers').send({
      id: '',
      userId: user.body.id,
      firstName: 'Sami',
      lastName: 'Kaci',
      phone: '0700000000',
      avatarUrl: null,
      vehicle: 'scooter',
      plateNumber: null,
      status: 'offline',
      documents: ['idCard', 'license', 'insurance'].map((type) => ({
        type,
        status: 'pending',
        uploadedAt: now,
      })),
      rating: 5,
      completedDeliveries: 0,
      totalEarnings: 0,
      zone: 'Paris',
      latitude: 48.8566,
      longitude: 2.3522,
      joinedAt: now,
    });
    expect(courier.status).toBe(201);
    expect(courier.body.userId).toBe(user.body.id);

    const clientProfile = await request(app).post('/api/couriers').send({
      userId: 'u-client-1',
      firstName: 'Alex',
      lastName: 'Martin',
    });
    expect(clientProfile.status).toBe(422);
  });

  test('le jeton mock du front suffit pour le profil, sans changer le rôle', async () => {
    const saved = await request(app)
      .put('/api/users/u-client-1')
      .set(auth('mock-token-u-client-1'))
      .send({
        id: 'u-client-1',
        firstName: 'Alexandre',
        lastName: 'Martin',
        email: 'alex.martin@exemple.fr',
        phone: '+33 6 24 46 56 22',
        role: 'admin',
        status: 'blocked',
        avatarUrl: null,
        restaurantId: null,
        loyaltyPoints: 9999,
        createdAt: new Date().toISOString(),
      });

    expect(saved.status).toBe(200);
    expect(saved.body.firstName).toBe('Alexandre');
    expect(saved.body.role).toBe('client');
    expect(saved.body.status).toBe('active');
    expect(saved.body.loyaltyPoints).toBe(340);

    const taken = await request(app)
      .put('/api/auth/me')
      .set(auth('mock-token-u-client-1'))
      .send({ email: 'admin@superfaster.fr' });
    expect(taken.status).toBe(409);
  });

  test('adresses, favoris et commandes vides pour la fiche profil', async () => {
    const token = auth('mock-token-u-client-1');
    const list = await request(app).get('/api/users/u-client-1/addresses').set(token);
    expect(list.status).toBe(200);
    expect(list.body.some((address) => address.isDefault && address.id === 'a-1')).toBe(true);

    const created = await request(app).post('/api/addresses').set(token).send({
      id: '',
      userId: 'u-client-1',
      label: 'Salle de sport',
      street: '8 rue Oberkampf',
      postalCode: '75011',
      city: 'Paris',
      type: 'other',
      instructions: null,
      isDefault: true,
      latitude: 48.8649,
      longitude: 2.3708,
    });
    expect(created.status).toBe(201);

    const defaults = await request(app)
      .patch(`/api/addresses/${created.body.id}/default`)
      .set(token);
    expect(defaults.status).toBe(200);
    expect(defaults.body.filter((address) => address.isDefault)).toHaveLength(1);

    const stranger = await request(app)
      .get('/api/users/u-client-1/addresses')
      .set(auth('mock-token-u-courier-1'));
    expect(stranger.status).toBe(403);

    const favorites = await request(app).get('/api/users/u-client-1/favorites').set(token);
    expect(favorites.body).toEqual([]);
    const added = await request(app).put('/api/users/u-client-1/favorites/r1').set(token);
    expect(added.status).toBe(204);
    const after = await request(app).get('/api/users/u-client-1/favorites').set(token);
    expect(after.body).toEqual(['r1']);

    const orders = await request(app).get('/api/orders').query({ userId: 'u-client-1' });
    expect(orders.body).toEqual([]);
  });
});
