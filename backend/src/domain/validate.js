const HttpError = require('../errors/http-error');

const EMAIL = /^[\w.+-]+@[\w-]+\.[\w.-]+$/;

function text(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function digits(value) {
  return text(value).replace(/[^0-9]/g, '');
}

function requireName(value) {
  const name = text(value);
  if (!name) throw new HttpError(422, 'Le nom est obligatoire');
  if (name.length < 2) throw new HttpError(422, 'Nom trop court');
  return name;
}

function requireEmail(value) {
  const email = text(value);
  if (!email) throw new HttpError(422, "L'e-mail est obligatoire");
  if (!EMAIL.test(email)) throw new HttpError(422, 'Adresse e-mail invalide');
  return email;
}

function requirePhone(value) {
  const phone = text(value);
  if (!digits(phone)) throw new HttpError(422, 'Le numéro est obligatoire');
  if (digits(phone).length < 9) {
    throw new HttpError(422, 'Numéro de téléphone invalide');
  }
  return phone;
}

function requirePassword(value) {
  if (value == null || value === '') {
    throw new HttpError(422, 'Le mot de passe est obligatoire');
  }
  if (typeof value !== 'string' || value.length < 6) {
    throw new HttpError(422, 'Au moins 6 caractères');
  }
  return value;
}

function optionalPassword(value) {
  if (value == null || value === '') return null;
  return requirePassword(value);
}

function requirePostalCode(value) {
  const code = text(value);
  if (!code) throw new HttpError(422, 'Le code postal est obligatoire');
  if (!/^\d{5}$/.test(code)) throw new HttpError(422, 'Code postal invalide');
  return code;
}

function oneOf(value, allowed, message) {
  if (!allowed.includes(value)) throw new HttpError(422, message);
  return value;
}

module.exports = {
  text,
  digits,
  requireName,
  requireEmail,
  requirePhone,
  requirePassword,
  optionalPassword,
  requirePostalCode,
  oneOf,
};
