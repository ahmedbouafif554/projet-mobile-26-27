const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const HttpError = require('../errors/http-error');
const { rounds } = require('../data/db');
const { publicUser, publicCourier } = require('../domain/presenters');
const {
  ROLES,
  SPACES,
  canAccess,
  roleMismatchMessage,
  MESSAGES,
} = require('../domain/roles');
const {
  text,
  requireName,
  requireEmail,
  requirePhone,
  requirePassword,
  oneOf,
} = require('../domain/validate');
const users = require('./users.service');
const couriers = require('./couriers.service');

/** Code affiché sur l'écran OTP du front (`AuthService.demoOtpCode`). */
const DEMO_OTP = '1234';

let dummyHash = null;
function dummyPasswordHash() {
  if (!dummyHash) dummyHash = bcrypt.hashSync('not-a-real-password', rounds());
  return dummyHash;
}

function signToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email },
    process.env.JWT_SECRET || 'changeme',
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
  );
}

/**
 * Mêmes gardes que `AuthService._open` : compte bloqué, restaurateur
 * encore en attente, puis espace (application mobile ou Espace Pro).
 */
async function openSession(user, space) {
  if (user.status === 'blocked') {
    throw new HttpError(403, MESSAGES.blocked);
  }
  if (user.role === 'restaurant' && user.status === 'pending') {
    throw new HttpError(403, MESSAGES.pendingRestaurant);
  }
  await couriers.assertApproved(user);
  if (space != null && !canAccess(user.role, space)) {
    throw new HttpError(
      403,
      space === 'backOffice' ? MESSAGES.backOfficeOnly : MESSAGES.frontOfficeOnly,
    );
  }
  const opened = await users.touchLogin(user);
  return { token: signToken(opened), user: publicUser(opened) };
}

/**
 * Inscription front office : client ou livreur uniquement.
 * La session du client s'ouvre tout de suite, sans code SMS.
 * Un livreur reçoit un profil en attente : il ne se connecte qu'après
 * validation de ses justificatifs par un administrateur.
 */
async function register(body) {
  const role = body.role ? oneOf(body.role, ROLES, MESSAGES.invalidRole) : 'client';
  if (role !== 'client' && role !== 'courier') {
    throw new HttpError(403, MESSAGES.registerInPro);
  }

  const documents = role === 'courier'
    ? couriers.requireRegistrationPhotos(body.documents)
    : null;

  const created = await users.create(
    {
      firstName: requireName(body.firstName),
      lastName: requireName(body.lastName),
      email: requireEmail(body.email),
      phone: requirePhone(body.phone),
      password: requirePassword(body.password),
      role,
    },
    null,
  );

  const stored = await users.findById(created.id);
  if (role === 'courier') {
    const courier = publicCourier(await couriers.ensureProfile(stored, documents));
    return {
      token: null,
      pendingApproval: true,
      message: MESSAGES.courierPending,
      user: publicUser(stored),
      courier,
    };
  }
  const session = await openSession(stored, 'frontOffice');
  return { token: session.token, user: session.user, courier: null };
}

async function login(body) {
  const password = typeof body.password === 'string' ? body.password : '';
  if (password.length < 6) throw new HttpError(401, MESSAGES.badPassword);

  const email = text(body.email);
  const user = await users.findByEmail(email);
  const matches = await bcrypt.compare(password, user?.passwordHash || dummyPasswordHash());
  if (!user) throw new HttpError(401, MESSAGES.unknownEmail);
  if (!matches) throw new HttpError(401, MESSAGES.badPassword);

  const role = body.role == null || body.role === '' ? null : body.role;
  if (role != null) oneOf(role, ROLES, MESSAGES.invalidRole);
  // Un compte mobile connecté avec le mauvais rôle : message du toggle.
  // Un compte Espace Pro n'est pas concerné (le contrôle d'espace suit).
  if (role && user.role !== role && canAccess(user.role, 'frontOffice')) {
    throw new HttpError(403, roleMismatchMessage(user.role));
  }

  const space = body.space == null || body.space === '' ? null : body.space;
  if (space != null) oneOf(space, SPACES, 'Espace invalide.');
  return openSession(user, space);
}

async function verifyOtp(body) {
  const code = text(body.code);
  if (code !== DEMO_OTP) throw new HttpError(400, MESSAGES.badOtp);
  const userId = text(body.userId);
  if (!userId) throw new HttpError(422, 'userId est obligatoire');
  const user = await users.mustFind(userId);
  return openSession(user, 'frontOffice');
}

async function profile(userId) {
  return users.get(userId);
}

function forgotPassword() {
  // Même réponse que l'e-mail existe ou non (écran « Mot de passe oublié »).
  // L'envoi du lien reste simulé, comme sur le frontend.
}

module.exports = {
  DEMO_OTP,
  register,
  login,
  verifyOtp,
  profile,
  forgotPassword,
  openSession,
};
