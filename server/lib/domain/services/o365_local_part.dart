// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

/// Thrown when a member's name cannot produce a usable local part (e.g.
/// both names are empty, or contain no characters valid in an email
/// address after normalization).
class O365LocalPartException implements Exception {
  final String message;
  const O365LocalPartException(this.message);

  @override
  String toString() => 'O365LocalPartException: $message';
}

/// Builds the `firstname.surname`-shaped local part of a tenant sign-in
/// address (the part before `@`) from a member's name.
///
/// Lowercases, strips diacritics (`é` -> `e`, `ü` -> `u`, ...), and drops
/// every character outside `[a-z0-9]` — this deliberately collapses
/// apostrophes ("O'Brien" -> "obrien"), hyphens ("Mary-Jane" -> "maryjane"),
/// and internal spaces ("van der Berg" -> "vanderberg") rather than
/// preserving them, since none of those characters are safe to assume valid
/// in every tenant's UPN policy. Not reversible and not unique — see
/// [O365MailboxConflictException] in `o365_sync_exception.dart` for how a
/// collision between two members with the same normalized name is handled.
String buildO365LocalPart({required String firstName, required String lastName}) {
  final first = _normalize(firstName);
  final last = _normalize(lastName);
  if (first.isEmpty && last.isEmpty) {
    throw const O365LocalPartException(
        'Member has no usable characters in their name for an email address');
  }
  if (first.isEmpty) return last;
  if (last.isEmpty) return first;
  return '$first.$last';
}

String _normalize(String input) {
  final stripped = _stripDiacritics(input.toLowerCase());
  return stripped.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _stripDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    buffer.write(_diacriticMap[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

// Covers Latin-1 Supplement + common Latin Extended-A letters likely to
// appear in Australian club membership rolls. Not exhaustive — an
// unmapped character simply falls through to the `[^a-z0-9]` strip above.
const Map<int, String> _diacriticMap = {
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a', 0x101: 'a', 0x103: 'a', 0x105: 'a',
  0xE7: 'c', 0x107: 'c', 0x109: 'c', 0x10B: 'c', 0x10D: 'c',
  0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e', 0x113: 'e', 0x115: 'e', 0x117: 'e', 0x119: 'e', 0x11B: 'e',
  0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i', 0x129: 'i', 0x12B: 'i', 0x12D: 'i', 0x12F: 'i',
  0xF1: 'n', 0x144: 'n', 0x146: 'n', 0x148: 'n',
  0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o', 0x14D: 'o', 0x14F: 'o', 0x151: 'o',
  0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u', 0x169: 'u', 0x16B: 'u', 0x16D: 'u', 0x16F: 'u', 0x171: 'u', 0x173: 'u',
  0xFD: 'y', 0xFF: 'y',
  0xE6: 'ae', 0x153: 'oe',
  0xDF: 'ss',
  0x11F: 'g', 0x11D: 'g',
  0x15F: 's', 0x15B: 's', 0x161: 's',
  0x163: 't', 0x165: 't',
  0x17A: 'z', 0x17C: 'z', 0x17E: 'z',
  0x142: 'l', 0x13E: 'l', 0x13C: 'l',
  0xF0: 'd', 0x111: 'd',
  0xFE: 'th',
};
