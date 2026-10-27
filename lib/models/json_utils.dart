/// Lenient readers shared by the model parsers.
///
/// NetEase payloads differ between endpoints (numbers as strings, `null`
/// instead of empty lists, nested maps typed as `Map<dynamic, dynamic>`), so
/// every model goes through these instead of casting directly.
library;

/// Integer from a number or numeric string, [fallback] otherwise.
int jsonInt(Object? value, [int fallback = 0]) =>
    jsonIntOrNull(value) ?? fallback;

/// Integer from a number or numeric string, `null` otherwise.
int? jsonIntOrNull(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// The string itself when [value] is a string, `null` otherwise.
String? jsonString(Object? value) => value is String ? value : null;

/// A string with visible content, `null` for missing / blank values.
String? jsonText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

/// `true` for `true`, `1` and `"true"`.
bool jsonBool(Object? value) => value == true || value == 1 || value == 'true';

/// [value] as a string keyed map, `null` when it is not a map.
Map<String, dynamic>? jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Every map inside [value], silently skipping anything else.
List<Map<String, dynamic>> jsonMaps(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) ?jsonMap(item)];
}

/// Non-empty strings inside [value].
List<String> jsonStrings(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}

/// Millisecond epoch timestamp, `null` when missing or not positive.
DateTime? jsonTime(Object? value) {
  final ms = jsonIntOrNull(value);
  if (ms == null || ms <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

/// Default artwork NetEase hands out when an entity has no picture.
const List<String> _placeholderImageIds = [
  '5639395138885805',
  '18686200114669622',
];

/// The first candidate that is a real image url (not the grey placeholder).
String? jsonImage(Iterable<Object?> candidates) {
  for (final candidate in candidates) {
    final url = jsonText(candidate);
    if (url == null) continue;
    if (_placeholderImageIds.any(url.contains)) continue;
    return url;
  }
  return null;
}
