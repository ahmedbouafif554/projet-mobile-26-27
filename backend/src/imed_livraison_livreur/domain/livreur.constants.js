'use strict';

/** Valeurs de `VehicleType`, `CourierStatus`, `DocumentType`, `DocumentStatus` (Flutter). */
const VEHICLES = Object.freeze(['bike', 'scooter', 'car']);
const COURIER_STATUSES = Object.freeze(['offline', 'available', 'busy']);
const DOCUMENT_TYPES = Object.freeze(['idCard', 'license', 'insurance']);
const DOCUMENT_STATUSES = Object.freeze(['pending', 'approved', 'rejected']);

const STATUS_LABELS = Object.freeze({
  offline: 'Hors ligne',
  available: 'Disponible',
  busy: 'En livraison',
});

/** Vitesse moyenne en ville (km/h) pour estimer une durée. */
const SPEEDS_KMH = Object.freeze({ bike: 15, scooter: 30, car: 25 });

/** Position par défaut : Paris centre. */
const DEFAULT_POSITION = Object.freeze({ latitude: 48.8566, longitude: 2.3522 });

const MESSAGES = Object.freeze({
  notFound: (id) => `Livreur introuvable (${id}).`,
  documentsNotApproved:
    'Vos justificatifs doivent être validés avant de recevoir des courses.',
  courierNotApproved: "Les justificatifs de ce livreur ne sont pas encore validés.",
  finishFirst: 'Terminez votre course avant de vous déconnecter.',
  busyWithoutDelivery: "Un livreur n'est « en livraison » que pendant une course.",
  activeDelivery: 'Ce livreur a une course en cours.',
  badVehicle: 'Véhicule invalide.',
  badStatus: 'Statut livreur invalide.',
  badDocumentType: 'Type de justificatif invalide.',
  badDocumentStatus: 'Statut de justificatif invalide.',
  badCoordinates: 'Coordonnées GPS invalides (latitude, longitude).',
});

/** Statut global des justificatifs, comme `Courier.documentStatus`. */
function documentStatusOf(documents) {
  const list = documents || [];
  if (list.length === 0) return 'pending';
  if (list.some((doc) => doc.status === 'rejected')) return 'rejected';
  return list.every((doc) => doc.status === 'approved') ? 'approved' : 'pending';
}

module.exports = {
  VEHICLES,
  COURIER_STATUSES,
  DOCUMENT_TYPES,
  DOCUMENT_STATUSES,
  STATUS_LABELS,
  SPEEDS_KMH,
  DEFAULT_POSITION,
  MESSAGES,
  documentStatusOf,
};
