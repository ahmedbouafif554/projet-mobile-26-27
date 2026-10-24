/// Petits utilitaires de conversion JSON partagés par les modèles du module.
library;

DateTime parseDate(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : DateTime.now();

DateTime? parseDateOrNull(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;

/// Enum depuis son nom JSON, avec une valeur de repli si inconnu.
T enumFromJson<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
