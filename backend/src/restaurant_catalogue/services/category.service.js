'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toSqlDate } = require('../../data/db');
const { MESSAGES } = require('../domain/catalogue.constants');
const { presentCategory } = require('../domain/catalogue.presenters');
const { requestedId, categoryInput, orderedIdsInput } = require('../domain/catalogue.validation');
const { isAdmin } = require('./access.service');
const { placeholders, insertRow, updateRow, findById } = require('./sql.utils');

const ORDER = 'ORDER BY position, name, id';

async function mustFind(id) {
  const row = await findById('categories', id);
  if (!row) throw new HttpError(404, MESSAGES.categoryNotFound);
  return row;
}

/** Comparaison en JavaScript : LOWER() de SQLite ignore les lettres accentuées. */
async function assertUniqueName(name, exceptId = null) {
  const key = name.toLocaleLowerCase('fr');
  const rows = await query('SELECT id, name FROM categories');
  if (rows.some((row) => row.id !== exceptId && row.name.toLocaleLowerCase('fr') === key)) {
    throw new HttpError(409, MESSAGES.duplicateCategoryName);
  }
}

/** Catégories dans l'ordre d'affichage (les inactives : administrateur seulement). */
async function list(actor) {
  const rows = isAdmin(actor)
    ? await query(`SELECT * FROM categories ${ORDER}`)
    : await query(`SELECT * FROM categories WHERE is_active = 1 ${ORDER}`);
  return rows.map(presentCategory);
}

async function get(actor, id) {
  const row = await mustFind(id);
  if (!isAdmin(actor) && Number(row.is_active) !== 1) {
    throw new HttpError(404, MESSAGES.categoryNotFound);
  }
  return presentCategory(row);
}

/** Une nouvelle catégorie se place en dernier. */
async function create(body) {
  const input = categoryInput(body);
  const id = requestedId(body.id) || newId('cat');
  if (await findById('categories', id)) throw new HttpError(409, MESSAGES.duplicateId);
  await assertUniqueName(input.name);

  const [{ last }] = await query('SELECT MAX(position) AS last FROM categories');
  await insertRow('categories', {
    id,
    name: input.name,
    emoji: input.emoji,
    color_value: input.colorValue,
    position: last == null ? 0 : Number(last) + 1,
    is_active: input.isActive ? 1 : 0,
    created_at: toSqlDate(new Date().toISOString()),
  });
  return presentCategory(await mustFind(id));
}

/** Nom, emoji, couleur et activation. La position change via `reorder`. */
async function update(id, body) {
  const current = presentCategory(await mustFind(id));
  const input = categoryInput({ ...current, ...body });
  await assertUniqueName(input.name, id);
  await updateRow('categories', id, {
    name: input.name,
    emoji: input.emoji,
    color_value: input.colorValue,
    is_active: input.isActive ? 1 : 0,
  });
  return presentCategory(await mustFind(id));
}

/** Renumérote 0, 1, 2… dans l'ordre donné (à appeler dans une transaction). */
async function writePositions(ids) {
  for (const [position, id] of ids.entries()) {
    await query('UPDATE categories SET position = ? WHERE id = ?', [position, id]);
  }
}

/**
 * Supprime la catégorie, la retire des restaurants et des produits, puis
 * referme le trou dans l'ordre d'affichage.
 */
async function remove(id) {
  await mustFind(id);
  await withTransaction(async () => {
    await query('DELETE FROM restaurant_categories WHERE category_id = ?', [id]);
    await query('UPDATE products SET category = NULL WHERE category = ?', [id]);
    await query('DELETE FROM categories WHERE id = ?', [id]);
    const remaining = await query(`SELECT id FROM categories ${ORDER}`);
    await writePositions(remaining.map((row) => row.id));
  });
}

/**
 * Nouvel ordre d'affichage (glisser-déposer du back office). Les catégories
 * absentes de la liste gardent leur ordre relatif, après celles listées.
 */
async function reorder(body) {
  const ids = orderedIdsInput(body?.ids);
  const existing = (await query(`SELECT id FROM categories ${ORDER}`)).map((row) => row.id);
  const unknown = ids.filter((id) => !existing.includes(id));
  if (unknown.length > 0) throw new HttpError(422, `Catégorie inconnue : ${unknown.join(', ')}.`);

  const ordered = [...ids, ...existing.filter((id) => !ids.includes(id))];
  await withTransaction(() => writePositions(ordered));
  return list({ role: 'admin' });
}

/** Vérifie que toutes les catégories citées existent (422 sinon). */
async function assertExist(ids) {
  if (ids.length === 0) return;
  const rows = await query(
    `SELECT id FROM categories WHERE id IN (${placeholders(ids.length)})`,
    ids,
  );
  const found = new Set(rows.map((row) => row.id));
  const missing = ids.filter((id) => !found.has(id));
  if (missing.length > 0) throw new HttpError(422, `Catégorie inconnue : ${missing.join(', ')}.`);
}

module.exports = { list, get, create, update, remove, reorder, assertExist };
