/// Petites fonctions de conversion JSON partagées par les modèles.
library;

DateTime parseDate(Object? value) => DateTime.parse(value as String);

DateTime? parseDateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

double parseDouble(Object? value, [double fallback = 0]) =>
    (value as num?)?.toDouble() ?? fallback;

int parseInt(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

/// Énumération à partir de son nom (`"pending"` → `OrderStatus.pending`).
T parseEnum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.asNameMap()[name] ?? fallback;

List<T> parseList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) => [
  for (final item in (value as List?) ?? const [])
    fromJson(item as Map<String, dynamic>),
];

List<String> parseStrings(Object? value) => [
  for (final item in (value as List?) ?? const []) item as String,
];

/// Sentinelle de `copyWith` : distingue « ne pas changer » de « mettre à null ».
const Object keep = _Keep();

class _Keep {
  const _Keep();
}
