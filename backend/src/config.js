'use strict';

/**
 * Configuration lue dans l'environnement (.env). Un seul endroit pour savoir
 * ce qui change entre développement, tests et production.
 */

const DEFAULT_SECRET = 'changeme';

function env(name, fallback = '') {
  const value = process.env[name];
  return value == null || value === '' ? fallback : String(value).trim();
}

function list(name) {
  return env(name)
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function flag(name, fallback) {
  const value = env(name);
  if (!value) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
}

const config = {
  get nodeEnv() {
    return env('NODE_ENV', 'development');
  },
  get isProduction() {
    return this.nodeEnv === 'production';
  },
  get isTest() {
    return this.nodeEnv === 'test';
  },

  get jwtSecret() {
    return env('JWT_SECRET', DEFAULT_SECRET);
  },
  get jwtExpiresIn() {
    return env('JWT_EXPIRES_IN', '7d');
  },

  /**
   * Jetons `mock-token-<id>` (posés par le front en mode démo, utilisés par
   * les tests). Jamais acceptés en dehors des tests : n'importe qui pourrait
   * se faire passer pour n'importe quel compte.
   */
  get allowMockTokens() {
    return this.isTest;
  },

  /** Code SMS de démonstration (`1234`) : interdit en production. */
  get allowDemoOtp() {
    return !this.isProduction && flag('ALLOW_DEMO_OTP', true);
  },

  /** Comptes de démonstration créés dans une base vide. */
  get seedDemo() {
    return flag('SEED_DEMO', !this.isProduction);
  },

  /** URL publique de l'API (liens des e-mails). */
  get publicUrl() {
    return env('PUBLIC_URL', `http://localhost:${env('PORT', '3001')}`).replace(/\/+$/, '');
  },

  /** Origines autorisées par CORS. Vide : toutes (développement). */
  get corsOrigins() {
    return list('CORS_ORIGINS');
  },

  /** Identifiants OAuth Google acceptés comme audience de l'ID token. */
  get googleClientIds() {
    return list('GOOGLE_CLIENT_IDS');
  },

  get smtp() {
    return {
      host: env('SMTP_HOST'),
      port: Number(env('SMTP_PORT', '587')),
      secure: flag('SMTP_SECURE', env('SMTP_PORT') === '465'),
      user: env('SMTP_USER'),
      pass: env('SMTP_PASS'),
      from: env('MAIL_FROM', env('SMTP_USER') || 'SuperFaster <no-reply@superfaster.local>'),
    };
  },

  /** Premier administrateur, créé au démarrage s'il n'existe aucun admin. */
  get bootstrapAdmin() {
    return {
      email: env('ADMIN_EMAIL'),
      password: env('ADMIN_PASSWORD'),
      firstName: env('ADMIN_FIRST_NAME', 'Admin'),
      lastName: env('ADMIN_LAST_NAME', 'SuperFaster'),
      phone: env('ADMIN_PHONE', '+33 6 00 00 00 00'),
    };
  },

  get trustProxy() {
    return flag('TRUST_PROXY', false);
  },
};

/**
 * Refuse de démarrer en production avec une configuration dangereuse.
 * Renvoie la liste des avertissements (non bloquants).
 */
function validate() {
  const errors = [];
  const warnings = [];
  if (config.isProduction) {
    if (config.jwtSecret === DEFAULT_SECRET || config.jwtSecret.length < 32) {
      errors.push('JWT_SECRET doit faire au moins 32 caractères aléatoires en production.');
    }
    if (config.corsOrigins.length === 0) {
      warnings.push('CORS_ORIGINS est vide : toutes les origines sont acceptées.');
    }
    if (!config.smtp.host) {
      warnings.push("SMTP_HOST est vide : les e-mails de réinitialisation ne sont pas envoyés (journal seulement).");
    }
    if (config.googleClientIds.length === 0) {
      warnings.push('GOOGLE_CLIENT_IDS est vide : la connexion Google est désactivée.');
    }
  } else if (config.jwtSecret === DEFAULT_SECRET) {
    warnings.push('JWT_SECRET non défini : secret de développement utilisé.');
  }
  if (errors.length) {
    const error = new Error(`Configuration invalide :\n- ${errors.join('\n- ')}`);
    error.configErrors = errors;
    throw error;
  }
  return warnings;
}

module.exports = config;
module.exports.validate = validate;
