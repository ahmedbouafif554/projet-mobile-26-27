'use strict';

/** Valeurs de `NotificationType`, `CampaignAudience`, `CampaignStatus` (Flutter). */
const NOTIFICATION_TYPES = Object.freeze(['order', 'promo', 'message', 'review', 'system']);
const AUDIENCES = Object.freeze(['all', 'clients', 'couriers', 'restaurants']);
const CAMPAIGN_STATUSES = Object.freeze(['draft', 'scheduled', 'sent']);
/** Canaux de `NotificationChannel` (écran « Préférences de notifications »). */
const CHANNELS = Object.freeze(['push', 'email', 'sms']);
const DEFAULT_CHANNELS = Object.freeze(['push', 'email']);

/** Audience d'une campagne → rôle des destinataires. */
const AUDIENCE_ROLE = Object.freeze({
  clients: 'client',
  couriers: 'courier',
  restaurants: 'restaurant',
});

/** Rôle d'un compte → audience qui le concerne. */
const ROLE_AUDIENCE = Object.freeze({
  client: 'clients',
  courier: 'couriers',
  restaurant: 'restaurants',
});

const LIMITS = Object.freeze({ title: 120, body: 1000, route: 300, imageUrl: 2000 });

const MESSAGES = Object.freeze({
  notFound: (id) => `Notification introuvable (${id}).`,
  campaignNotFound: (id) => `Campagne introuvable (${id}).`,
  titleRequired: 'Le titre est obligatoire.',
  titleTooLong: `Le titre est limité à ${LIMITS.title} caractères.`,
  bodyRequired: 'Le message est obligatoire.',
  bodyTooLong: `Le message est limité à ${LIMITS.body} caractères.`,
  badType: 'Type de notification invalide.',
  badAudience: 'Audience invalide.',
  badCampaignStatus: 'Statut de campagne invalide.',
  badRoute: 'Le lien doit être un chemin de l’application (ex. /orders/123).',
  badDate: 'Date invalide.',
  scheduleRequired: "Choisissez la date d'envoi de la campagne programmée.",
  scheduleInPast: "La date d'envoi doit être dans le futur.",
  alreadySent: 'Cette campagne a déjà été envoyée.',
  sentLocked: 'Une campagne envoyée ne peut plus être modifiée.',
  idTaken: 'Cet identifiant est déjà utilisé.',
  ownOnly: 'Vous ne pouvez créer une notification que pour vous-même.',
  badSettings: 'Préférences de notifications invalides.',
});

module.exports = {
  NOTIFICATION_TYPES,
  AUDIENCES,
  CAMPAIGN_STATUSES,
  CHANNELS,
  DEFAULT_CHANNELS,
  AUDIENCE_ROLE,
  ROLE_AUDIENCE,
  LIMITS,
  MESSAGES,
};
