/**
 * Rôles et espaces, calqués sur `UserRole`, `AppSpace` et `Permissions`
 * du frontend. Les noms sont ceux de `enum.name` (pas les libellés affichés).
 */

const ROLES = Object.freeze(['client', 'courier', 'restaurant', 'admin']);
const USER_STATUSES = Object.freeze(['active', 'blocked', 'pending']);
const SPACES = Object.freeze(['frontOffice', 'backOffice']);

const ROLE_LABEL = Object.freeze({
  client: 'Client',
  courier: 'Livreur',
  restaurant: 'Restaurant',
  admin: 'Administrateur',
});

const FRONT_OFFICE = new Set(['client', 'courier']);

function spaceOf(role) {
  if (FRONT_OFFICE.has(role)) return 'frontOffice';
  if (role === 'restaurant' || role === 'admin') return 'backOffice';
  return null;
}

function canAccess(role, space) {
  return spaceOf(role) === space;
}

/** Message du front quand le rôle coché ne correspond pas au compte. */
function roleMismatchMessage(role) {
  const label = ROLE_LABEL[role] || role;
  return `Ce compte est un compte ${label.toLowerCase()} : sélectionnez « ${label} ».`;
}

const MESSAGES = Object.freeze({
  badPassword: 'Mot de passe incorrect.',
  unknownEmail: 'Aucun compte ne correspond à cet e-mail.',
  blocked: 'Ce compte est bloqué. Contactez le support.',
  pendingRestaurant:
    'Votre inscription est en cours de validation par notre équipe.',
  courierPending:
    'Votre compte livreur est en attente de validation par un administrateur.',
  courierRejected:
    'Vos justificatifs ont été refusés. Vous ne pouvez pas vous connecter.',
  backOfficeOnly:
    "L'Espace Pro est réservé aux restaurants et à l'administration.",
  frontOfficeOnly: "Ce compte n'a pas accès à l'application mobile.",
  registerInPro: "Ce type de compte s'inscrit dans l'Espace Pro.",
  duplicateEmail: 'Un compte existe déjà avec cet e-mail.',
  badOtp: 'Code incorrect, veuillez réessayer.',
  invalidRole: 'Rôle invalide.',
  invalidStatus: 'Statut invalide.',
  ownRole: 'Vous ne pouvez pas modifier votre propre rôle.',
  ownBlock: 'Vous ne pouvez pas bloquer votre propre compte.',
  forbidden: "Vous n'avez pas accès à cette ressource.",
});

module.exports = {
  ROLES,
  USER_STATUSES,
  SPACES,
  ROLE_LABEL,
  spaceOf,
  canAccess,
  roleMismatchMessage,
  MESSAGES,
};
