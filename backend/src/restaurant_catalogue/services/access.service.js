'use strict';

const HttpError = require('../../errors/http-error');
const users = require('../../services/users.service');
const { MESSAGES } = require('../../domain/roles');
const { APPROVED, MESSAGES: CATALOGUE } = require('../domain/catalogue.constants');

/**
 * Qui peut voir et gérer un restaurant (et donc ses produits) :
 *  - administrateur : tout ;
 *  - restaurateur : son restaurant (propriétaire déclaré `owner_id`, ou
 *    restaurant rattaché à son compte `users.restaurant_id`) ;
 *  - tout le monde : les restaurants validés, en lecture seule.
 */

function isAdmin(actor) {
  return actor?.role === 'admin';
}

/** Restaurant rattaché au compte restaurateur connecté (ou `null`). */
async function linkedRestaurantId(actor) {
  if (actor?.role !== 'restaurant') return null;
  const user = await users.findById(actor.id);
  return user?.restaurantId || null;
}

async function ownsRestaurant(actor, restaurant) {
  if (actor?.role !== 'restaurant' || !restaurant) return false;
  if (restaurant.owner_id === actor.id) return true;
  return (await linkedRestaurantId(actor)) === restaurant.id;
}

async function canManage(actor, restaurant) {
  return isAdmin(actor) || ownsRestaurant(actor, restaurant);
}

async function canView(actor, restaurant) {
  return restaurant.status === APPROVED || canManage(actor, restaurant);
}

/**
 * Lecture : un restaurant non validé n'existe pas pour ceux qui ne le gèrent
 * pas (404 plutôt que 403, pour ne pas révéler les demandes en attente).
 */
async function assertCanView(actor, restaurant, notFound = CATALOGUE.restaurantNotFound) {
  if (!restaurant || !(await canView(actor, restaurant))) {
    throw new HttpError(404, notFound);
  }
}

async function assertCanManage(actor, restaurant, notFound = CATALOGUE.restaurantNotFound) {
  if (!restaurant) throw new HttpError(404, notFound);
  if (await canManage(actor, restaurant)) return;
  if (await canView(actor, restaurant)) throw new HttpError(403, MESSAGES.forbidden);
  throw new HttpError(404, notFound);
}

/**
 * Filtre SQL des restaurants visibles par `actor` (alias de table `alias`).
 * Renvoie `null` pour l'administrateur (aucun filtre).
 */
async function visibilityFilter(actor, alias) {
  if (isAdmin(actor)) return null;
  if (actor?.role !== 'restaurant') {
    return { sql: `${alias}.status = ?`, params: [APPROVED] };
  }
  return {
    sql: `(${alias}.status = ? OR ${alias}.owner_id = ? OR ${alias}.id = ?)`,
    params: [APPROVED, actor.id, (await linkedRestaurantId(actor)) || ''],
  };
}

module.exports = {
  isAdmin,
  linkedRestaurantId,
  canManage,
  canView,
  assertCanView,
  assertCanManage,
  visibilityFilter,
};
