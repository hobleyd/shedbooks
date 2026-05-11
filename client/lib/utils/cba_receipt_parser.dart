import 'receipt_format.dart';

/// Parses a CBA bank statement debit description into a list of receipt numbers
/// that match [format].
///
/// CBA groups multiple payments in a single debit row using a compact range
/// notation. Examples (with format `P-?YY###`, year 2026):
///   `P26062-67,69`      → P-26062 through P-26067, plus P-26069
///   `P-26001-10,12,14`  → P-26001 through P-26010, P-26012, P-26014
///   `P-26075`           → P-26075 only
///
/// Abbreviated suffixes are expanded relative to the base number: in `P26062-67`
/// the base is `26062` (5 digits), so `67` expands to `26067` (prefix `260`).
/// Out-of-order or ambiguous suffixes are silently skipped.
///
/// Returns an empty list when [format] is empty or no match is found.
List<String> parseCbaReceiptNumbers(
  String description,
  ReceiptFormat format, {
  DateTime? at,
}) {
  if (format.isEmpty) return [];

  final now = at ?? DateTime.now();
  final baseMatch = format.toUnanchoredRegExp(at: now).firstMatch(description);
  if (baseMatch == null) return [];

  final matchedText = baseMatch.group(0)!;
  // Strip all non-digit characters to get the numeric key used for expansion.
  final baseStr = matchedText.replaceAll(RegExp(r'[^0-9]'), '');
  if (baseStr.isEmpty) return [matchedText];

  // Look for CBA range/comma notation immediately after the match.
  final rest =
      RegExp(r'^[-,\d]+').stringMatch(description.substring(baseMatch.end)) ??
          '';

  // Canonical prefix (e.g. "P-") used to normalise all output numbers.
  final prefix = format.canonicalPrefix;
  final digitLen = baseStr.length;

  if (rest.isEmpty) {
    return ['$prefix${baseStr.padLeft(digitLen, '0')}'];
  }

  final numbers = <int>[int.parse(baseStr)];

  for (final m in RegExp(r'([-,])(\d+)').allMatches(rest)) {
    final sep = m.group(1)!;
    final abbrev = m.group(2)!;
    final prefixLen = digitLen - abbrev.length;
    final n = prefixLen > 0
        ? int.parse(baseStr.substring(0, prefixLen) + abbrev)
        : int.parse(abbrev);

    if (n <= numbers.last) continue; // out-of-order or ambiguous

    if (sep == '-') {
      for (int x = numbers.last + 1; x <= n; x++) {
        numbers.add(x);
      }
    } else {
      numbers.add(n);
    }
  }

  return numbers
      .map((n) => '$prefix${n.toString().padLeft(digitLen, '0')}')
      .toList();
}

/// Finds a single receipt number in [description] that matches [format].
///
/// Used for credit (money-in) rows where CBA records a single receipt.
/// Returns `null` when [format] is empty or no match is found.
String? extractCreditReceipt(
  String description,
  ReceiptFormat format, {
  DateTime? at,
}) {
  if (format.isEmpty) return null;
  final now = at ?? DateTime.now();
  return format.toUnanchoredRegExp(at: now).firstMatch(description)?.group(0);
}
