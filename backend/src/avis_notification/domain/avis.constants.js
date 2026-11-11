'use strict';

/** Valeurs de `ReviewStatus` (Flutter). */
const REVIEW_STATUSES = Object.freeze(['pending', 'approved', 'rejected']);

const STATUS_LABELS = Object.freeze({
  pending: 'En attente',
  approved: 'Publié',
  rejected: 'Refusé',
});

const LIMITS = Object.freeze({
  comment: 1000,
  reply: 1000,
  photos: 6,
  photoLength: 2_200_000,
  reportReason: 300,
});

/** Nom affiché d'une réponse de l'administration (comme dans le back office). */
const ADMIN_REPLY_AUTHOR = 'Équipe SuperFaster';

const MESSAGES = Object.freeze({
  notFound: (id) => `Avis introuvable (${id}).`,
  onlyClients: 'Seuls les clients peuvent laisser un avis.',
  orderNotFound: (id) => `Commande introuvable (${id}).`,
  notYourOrder: "Cette commande n'est pas la vôtre.",
  notDelivered: 'Vous pourrez noter cette commande une fois livrée.',
  alreadyReviewed: 'Vous avez déjà laissé un avis pour cette commande.',
  restaurantMismatch: "Le restaurant ne correspond pas à celui de la commande.",
  restaurantRequired: 'restaurantId est obligatoire.',
  restaurantNotFound: (id) => `Restaurant introuvable (${id}).`,
  noOrderAtRestaurant: 'Commandez dans ce restaurant avant de laisser un avis.',
  badRating: 'La note doit être un entier de 1 à 5.',
  badCriterion: (name) => `La note « ${name} » doit être un entier de 1 à 5.`,
  commentTooLong: `Le commentaire est limité à ${LIMITS.comment} caractères.`,
  badPhotos: `Jusqu'à ${LIMITS.photos} photos (liens ou images).`,
  badStatus: 'Statut d’avis invalide.',
  replyEmpty: 'La réponse ne peut pas être vide.',
  replyTooLong: `La réponse est limitée à ${LIMITS.reply} caractères.`,
  replyNotPublished: 'Seul un avis publié peut recevoir une réponse.',
  notPublished: "Cet avis n'est pas publié.",
});

module.exports = {
  REVIEW_STATUSES,
  STATUS_LABELS,
  LIMITS,
  ADMIN_REPLY_AUTHOR,
  MESSAGES,
};
