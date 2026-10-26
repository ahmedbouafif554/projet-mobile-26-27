/** Erreur métier renvoyée telle quelle par le gestionnaire Express. */
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

module.exports = HttpError;
