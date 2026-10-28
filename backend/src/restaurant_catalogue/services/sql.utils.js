'use strict';

const { query } = require('../../data/db');

/**
 * Petites requêtes génériques. Les noms de table et de colonne viennent
 * toujours du code du module, jamais de la requête HTTP : seules les valeurs
 * sont passées en paramètres.
 */

function placeholders(count) {
  return Array.from({ length: count }, () => '?').join(', ');
}

function insertRow(table, values) {
  const columns = Object.keys(values);
  return query(
    `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders(columns.length)})`,
    Object.values(values),
  );
}

function updateRow(table, id, values) {
  const columns = Object.keys(values);
  return query(
    `UPDATE ${table} SET ${columns.map((column) => `${column} = ?`).join(', ')} WHERE id = ?`,
    [...Object.values(values), id],
  );
}

async function findById(table, id) {
  const rows = await query(`SELECT * FROM ${table} WHERE id = ? LIMIT 1`, [id]);
  return rows[0] || null;
}

/** Suppression refusée par une clé étrangère d'un autre module (message SQLite). */
function isForeignKeyError(error) {
  return /FOREIGN KEY constraint failed/i.test(error?.message || '');
}

module.exports = { placeholders, insertRow, updateRow, findById, isForeignKeyError };
