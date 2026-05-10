/// Returns a field-level diff between [before] and [after] maps.
///
/// Only fields whose string representation changed are included in the result.
/// Each changed field maps to `{'from': oldValue, 'to': newValue}`.
Map<String, dynamic> diffMaps(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final result = <String, dynamic>{};
  for (final key in after.keys) {
    final b = before[key];
    final a = after[key];
    if (b?.toString() != a?.toString()) {
      result[key] = {'from': b, 'to': a};
    }
  }
  return result;
}
