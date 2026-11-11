'use strict';

const { query } = require('../../data/db');
const { haversineDistance } = require('./geo.utils');

/** Rayon autour du restaurant dans lequel les livreurs sont prévenus (km). */
const NOTIFY_RADIUS_KM = 15;
/** Nombre maximum de livreurs prévenus pour une même course. */
const NOTIFY_LIMIT = 10;

/** Route de l'app livreur ouverte au toucher de la notification. */
const COURIER_DELIVERIES_ROUTE = '/courier/deliveries';

/** Adresse lisible d'une adresse de livraison (objet `Address` ou texte). */
function addressLabel(address) {
  if (!address) return 'Adresse du client';
  if (typeof address === 'string') return address;
  const parts = [address.street, [address.postalCode, address.city].filter(Boolean).join(' ')].filter(Boolean);
  return parts.join(', ') || 'Adresse du client';
}

/**
 * Livreurs à prévenir : disponibles, avec un compte actif, les plus proches
 * du restaurant (dans [NOTIFY_RADIUS_KM]). Si aucun n'est assez proche, tous
 * les livreurs disponibles sont prévenus pour que la course ne reste pas
 * sans réponse.
 */
async function couriersToNotify(pickupLat, pickupLng) {
  const rows = await query(
    `SELECT c.id, c.user_id, c.latitude, c.longitude
       FROM couriers c JOIN users u ON u.id = c.user_id
      WHERE c.status = 'available' AND u.status = 'active'`,
  );
  const scored = rows.map((c) => ({
    ...c,
    distanceKm: c.latitude == null || c.longitude == null
      ? null
      : haversineDistance(pickupLat, pickupLng, Number(c.latitude), Number(c.longitude)),
  }));
  const nearby = scored
    .filter((c) => c.distanceKm != null && c.distanceKm <= NOTIFY_RADIUS_KM)
    .sort((a, b) => a.distanceKm - b.distanceKm);
  return (nearby.length ? nearby : scored).slice(0, NOTIFY_LIMIT);
}

/**
 * Prévient les livreurs qu'une nouvelle course est disponible, avec l'adresse
 * exacte (placée sur la carte par le client) et la distance de la course.
 * N'échoue jamais : une notification manquée ne doit pas annuler la commande.
 *
 * @returns {Promise<string[]>} identifiants des comptes livreurs prévenus.
 */
async function notifyCouriersOfNewDelivery({ order, restaurant, deliveryAddress, pickup, dropoff, distanceKm, fee }) {
  try {
    const avisNotification = require('../../avis_notification');
    await avisNotification.init();
    const couriers = await couriersToNotify(pickup.latitude, pickup.longitude);
    const where = addressLabel(deliveryAddress);
    const gps = `${dropoff.latitude.toFixed(5)}, ${dropoff.longitude.toFixed(5)}`;
    const notified = [];
    for (const courier of couriers) {
      const away = courier.distanceKm == null ? '' : ` · à ${courier.distanceKm} km de vous`;
      await avisNotification.notificationService.notify(courier.user_id, {
        title: 'Nouvelle course disponible 🛵',
        body:
          `${restaurant.name || 'Restaurant'} → ${where} (GPS ${gps}) · ` +
          `${distanceKm} km · ${Number(fee).toFixed(2).replace('.', ',')} €${away} · ` +
          `commande #${order.reference}`,
        type: 'order',
        route: COURIER_DELIVERIES_ROUTE,
      });
      notified.push(courier.user_id);
    }
    return notified;
  } catch (error) {
    if (process.env.NODE_ENV !== 'test') {
      console.error(`Notification des livreurs impossible : ${error.message}`);
    }
    return [];
  }
}

module.exports = {
  notifyCouriersOfNewDelivery,
  couriersToNotify,
  NOTIFY_RADIUS_KM,
};
