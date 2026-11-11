'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { authenticate, optionalAuth } = require('../../middleware/auth.middleware');
const { schemaReady } = require('../data/schema');
const avis = require('../controllers/avis.controller');
const notif = require('../controllers/notification.controller');

const h = asyncHandler;

/** `/api/reviews` — contrat de `ApiReviewRepository` + modération avancée. */
const reviewRoutes = express.Router();
reviewRoutes.use(schemaReady);
reviewRoutes.get('/', optionalAuth, h(avis.list));
reviewRoutes.post('/', authenticate, h(avis.create));
reviewRoutes.get('/stats', optionalAuth, h(avis.stats));
reviewRoutes.get('/:id', optionalAuth, h(avis.get));
reviewRoutes.put('/:id', authenticate, h(avis.update));
reviewRoutes.delete('/:id', authenticate, h(avis.remove));
reviewRoutes.patch('/:id/status', authenticate, h(avis.moderate));
reviewRoutes.patch('/:id/reply', authenticate, h(avis.reply));
reviewRoutes.put('/:id/reply', authenticate, h(avis.reply));
reviewRoutes.delete('/:id/reply', authenticate, h(avis.deleteReply));
reviewRoutes.post('/:id/helpful', authenticate, h(avis.markHelpful));
reviewRoutes.delete('/:id/helpful', authenticate, h(avis.unmarkHelpful));
reviewRoutes.post('/:id/report', authenticate, h(avis.report));
reviewRoutes.get('/:id/reports', authenticate, h(avis.reports));

/**
 * Sous-routes greffées sur `/api/restaurants` : seules ces deux adresses sont
 * définies, tout le reste retombe sur le module catalogue.
 */
const restaurantReviewRoutes = express.Router();
restaurantReviewRoutes.get('/:restaurantId/reviews', schemaReady, optionalAuth, h(avis.forRestaurant));
restaurantReviewRoutes.get('/:restaurantId/reviews/stats', schemaReady, optionalAuth, h(avis.restaurantStats));

/** `/api/notifications` — contrat de `ApiNotificationRepository`. */
const notificationRoutes = express.Router();
notificationRoutes.use(schemaReady, authenticate);
notificationRoutes.get('/', h(notif.list));
notificationRoutes.post('/', h(notif.create));
notificationRoutes.get('/:id', h(notif.get));
notificationRoutes.put('/:id', h(notif.update));
notificationRoutes.delete('/:id', h(notif.remove));
notificationRoutes.patch('/:id/read', h(notif.markRead));
notificationRoutes.post('/:id/read', h(notif.markRead));

/**
 * Sous-routes greffées sur `/api/users` (le reste retombe sur le module
 * utilisateurs). Le jeton est vérifié route par route pour ne pas bloquer
 * les autres adresses `/api/users`.
 */
const userNotificationRoutes = express.Router();
const u = [schemaReady, authenticate];
userNotificationRoutes.get('/:userId/notifications', ...u, h(notif.forUser));
userNotificationRoutes.get('/:userId/notifications/unread-count', ...u, h(notif.unreadCount));
userNotificationRoutes.post('/:userId/notifications/read-all', ...u, h(notif.markAllRead));
userNotificationRoutes.patch('/:userId/notifications/read-all', ...u, h(notif.markAllRead));
userNotificationRoutes.delete('/:userId/notifications/read', ...u, h(notif.clearRead));
userNotificationRoutes.get('/:userId/notification-settings', ...u, h(notif.getSettings));
userNotificationRoutes.put('/:userId/notification-settings', ...u, h(notif.saveSettings));

/** `/api/campaigns` — contrat de `ApiCampaignRepository` (admin). */
const campaignRoutes = express.Router();
campaignRoutes.use(schemaReady, authenticate);
campaignRoutes.get('/', h(notif.listCampaigns));
campaignRoutes.post('/', h(notif.createCampaign));
campaignRoutes.get('/:id', h(notif.getCampaign));
campaignRoutes.put('/:id', h(notif.updateCampaign));
campaignRoutes.delete('/:id', h(notif.removeCampaign));
campaignRoutes.patch('/:id/send', h(notif.sendCampaign));
campaignRoutes.post('/:id/send', h(notif.sendCampaign));

module.exports = {
  reviewRoutes,
  restaurantReviewRoutes,
  notificationRoutes,
  userNotificationRoutes,
  campaignRoutes,
};
