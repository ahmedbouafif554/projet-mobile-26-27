'use strict';

/**
 * Localise avec OpenStreetMap les restaurants jamais localisés ou en erreur
 * (par exemple ceux créés avant cette fonctionnalité ou hors connexion).
 *
 *   npm run geocode:catalogue
 *
 * Une requête par seconde au plus : compter environ une seconde par restaurant.
 * Relancer la commande ne redemande que les restaurants encore à localiser.
 */

require('dotenv').config();
const { init, close } = require('../../data/db');
const restaurantCatalogue = require('..');

async function geocodeCatalogue() {
  await init();
  await restaurantCatalogue.init();
  const counts = await restaurantCatalogue.restaurantService.locatePending();
  console.log(
    `Localisation des restaurants : ${counts.ok} trouvés, ${counts.not_found} adresses introuvables,` +
      ` ${counts.error} à réessayer (service indisponible).`,
  );
}

geocodeCatalogue()
  .catch((error) => {
    console.error(`Échec de la localisation : ${error.message}`);
    process.exitCode = 1;
  })
  .finally(close);
