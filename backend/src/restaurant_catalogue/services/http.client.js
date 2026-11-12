'use strict';

const settings = require('../catalogue.config');

/** Service externe injoignable, trop lent ou réponse illisible. */
class ExternalServiceError extends Error {
  constructor(service, reason) {
    super(`${service} : ${reason}`);
    this.name = 'ExternalServiceError';
    this.service = service;
  }
}

/**
 * GET JSON vers une API publique, avec un délai maximal et un User-Agent qui
 * identifie l'application (exigé par Nominatim et Open Food Facts).
 * Renvoie `null` si le service répond 404 (élément inconnu).
 */
async function getJson(service, url) {
  let response;
  try {
    response = await fetch(url, {
      headers: {
        'User-Agent': settings.userAgent,
        Accept: 'application/json',
        'Accept-Language': 'fr',
      },
      signal: AbortSignal.timeout(settings.timeoutMs),
    });
  } catch (error) {
    const reason = error?.name === 'TimeoutError' ? 'délai dépassé' : 'injoignable';
    throw new ExternalServiceError(service, reason);
  }
  if (response.status === 404) return null;
  if (!response.ok) throw new ExternalServiceError(service, `HTTP ${response.status}`);
  try {
    return await response.json();
  } catch {
    throw new ExternalServiceError(service, 'réponse illisible');
  }
}

module.exports = { getJson, ExternalServiceError };
