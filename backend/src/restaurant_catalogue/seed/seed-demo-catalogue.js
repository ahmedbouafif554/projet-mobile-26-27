'use strict';

/**
 * Charge le catalogue de démonstration du frontend (`MockCatalog` :
 * 10 restaurants et 41 produits) dans la base SQLite, pour que le front office
 * et le back office partagent les mêmes données.
 *
 *   npm run seed:catalogue
 *
 * Idempotent : un restaurant ou un produit déjà présent (même identifiant)
 * n'est pas modifié. Les données passent par les services du module, donc
 * par la même validation que l'API.
 */

require('dotenv').config();
const { init, close, query } = require('../../data/db');
const users = require('../../services/users.service');
const restaurantCatalogue = require('..');
const demo = require('./demo-catalogue.json');

const ADMIN = Object.freeze({ id: 'seed', role: 'admin' });

async function existingIds(table) {
  return new Set((await query(`SELECT id FROM ${table}`)).map((row) => row.id));
}

/** Les comptes restaurateurs absents de la base ne sont pas rattachés. */
async function ownerIdFor(restaurant) {
  if (!restaurant.ownerId) return null;
  const owner = await users.findById(restaurant.ownerId);
  return owner?.role === 'restaurant' ? owner.id : null;
}

async function seed() {
  await init();
  await restaurantCatalogue.init();
  const counts = { restaurants: 0, products: 0, skipped: 0 };

  const restaurantIds = await existingIds('restaurants');
  for (const restaurant of demo.restaurants) {
    if (restaurantIds.has(restaurant.id)) {
      counts.skipped += 1;
      continue;
    }
    await restaurantCatalogue.restaurantService.create(ADMIN, {
      ...restaurant,
      ownerId: await ownerIdFor(restaurant),
    });
    counts.restaurants += 1;
  }

  const productIds = await existingIds('products');
  for (const product of demo.products) {
    if (productIds.has(product.id)) {
      counts.skipped += 1;
      continue;
    }
    await restaurantCatalogue.productService.create(ADMIN, product);
    counts.products += 1;
  }

  console.log(
    `Catalogue de démo : ${counts.restaurants} restaurants et ${counts.products} produits ajoutés` +
      ` (${counts.skipped} déjà présents).`,
  );
}

seed()
  .catch((error) => {
    console.error(`Échec du chargement du catalogue : ${error.message}`);
    process.exitCode = 1;
  })
  .finally(close);
