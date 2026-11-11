'use strict';

/** Horodatage ISO (UTC) écrit par ce module. */
function nowIso() {
  return new Date().toISOString();
}

/**
 * Lecture d'une date stockée. `CURRENT_TIMESTAMP` de SQLite donne
 * « AAAA-MM-JJ HH:MM:SS » en UTC sans fuseau : on ajoute le « Z » pour
 * qu'elle ne soit pas relue comme une heure locale.
 */
function iso(value) {
  if (value == null || value === '') return null;
  let text = String(value);
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d+)?$/.test(text)) {
    text = `${text.replace(' ', 'T')}Z`;
  }
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function sameLocalDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function localDayKey(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

module.exports = { nowIso, iso, sameLocalDay, localDayKey };
