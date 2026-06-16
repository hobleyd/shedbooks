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

/// Parses and applies a receipt number format pattern.
///
/// Token reference:
///   `YYYY`  — 4-digit year (e.g. 2026)
///   `YY`    — 2-digit year (e.g. 26)
///   `#`     — any digit
///   `@`     — any letter
///   `*`     — any alphanumeric character
///   `x?`    — literal character x is optional (e.g. `-?` makes dash optional)
///   other   — literal character (required)
///
/// Empty pattern means no format is enforced (matches everything).
class ReceiptFormat {
  final String pattern;

  const ReceiptFormat(this.pattern);

  bool get isEmpty => pattern.trim().isEmpty;

  /// Returns a sample string that matches this format using [at] as the
  /// reference date (defaults to today).
  String example({DateTime? at}) {
    final now = at ?? DateTime.now();
    final sb = StringBuffer();
    for (final t in _tokenize()) {
      switch (t.token) {
        case 'YYYY':
          sb.write(now.year.toString().padLeft(4, '0'));
        case 'YY':
          sb.write((now.year % 100).toString().padLeft(2, '0'));
        case '#':
          sb.write('0');
        case '@':
          sb.write('A');
        case '*':
          sb.write('0');
        default:
          sb.write(t.token);
      }
    }
    return sb.toString();
  }

  /// The leading literal characters before the first wildcard or year token.
  ///
  /// Used to normalise reconstructed receipt numbers to a canonical form
  /// (e.g. `P-?YY###` → `"P-"`).  Optional literals are included so the
  /// output is always in the "full" form.
  String get canonicalPrefix {
    final sb = StringBuffer();
    for (final t in _tokenize()) {
      switch (t.token) {
        case 'YYYY':
        case 'YY':
        case '#':
        case '@':
        case '*':
          return sb.toString();
        default:
          sb.write(t.token);
      }
    }
    return sb.toString();
  }

  /// Returns a [RegExp] that matches strings conforming to this format for
  /// the given reference date.
  RegExp toRegExp({DateTime? at}) {
    final now = at ?? DateTime.now();
    final sb = StringBuffer('^');
    for (final t in _tokenize()) {
      switch (t.token) {
        case 'YYYY':
          sb.write(now.year.toString().padLeft(4, '0'));
        case 'YY':
          sb.write((now.year % 100).toString().padLeft(2, '0'));
        case '#':
          sb.write(r'\d');
        case '@':
          sb.write('[a-zA-Z]');
        case '*':
          sb.write('[a-zA-Z0-9]');
        default:
          final escaped = RegExp.escape(t.token);
          sb.write(t.optional ? '$escaped?' : escaped);
      }
    }
    sb.write(r'$');
    return RegExp(sb.toString());
  }

  /// Returns a [RegExp] suitable for searching within a larger string (no
  /// `^` / `$` anchors).
  RegExp toUnanchoredRegExp({DateTime? at}) {
    final now = at ?? DateTime.now();
    final sb = StringBuffer();
    for (final t in _tokenize()) {
      switch (t.token) {
        case 'YYYY':
          sb.write(now.year.toString().padLeft(4, '0'));
        case 'YY':
          sb.write((now.year % 100).toString().padLeft(2, '0'));
        case '#':
          sb.write(r'\d');
        case '@':
          sb.write('[a-zA-Z]');
        case '*':
          sb.write('[a-zA-Z0-9]');
        default:
          final escaped = RegExp.escape(t.token);
          sb.write(t.optional ? '$escaped?' : escaped);
      }
    }
    return RegExp(sb.toString());
  }

  /// Returns true if [receipt] matches this format, or if the format is empty.
  bool matches(String receipt, {DateTime? at}) =>
      isEmpty || toRegExp(at: at).hasMatch(receipt);

  /// Returns the next sequential receipt number by scanning [existing] receipts
  /// that match this format for [at]'s year and incrementing the highest number
  /// found in the `#` digit positions. Falls back to [example] when the format
  /// has no `#` tokens or is empty.
  String nextReceipt(List<String> existing, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final tokens = _tokenize();
    final digitCount = tokens.where((t) => t.token == '#').length;
    if (digitCount == 0) return example(at: now);

    // Build a regex that captures each # digit individually.
    final reSb = StringBuffer('^');
    for (final t in tokens) {
      switch (t.token) {
        case 'YYYY':
          reSb.write(now.year.toString().padLeft(4, '0'));
        case 'YY':
          reSb.write((now.year % 100).toString().padLeft(2, '0'));
        case '#':
          reSb.write(r'(\d)');
        case '@':
          reSb.write('[a-zA-Z]');
        case '*':
          reSb.write('[a-zA-Z0-9]');
        default:
          final esc = RegExp.escape(t.token);
          reSb.write(t.optional ? '$esc?' : esc);
      }
    }
    reSb.write(r'$');
    final re = RegExp(reSb.toString(), caseSensitive: false);

    int maxNum = 0;
    for (final receipt in existing) {
      final m = re.firstMatch(receipt);
      if (m == null) continue;
      final digits =
          [for (int i = 1; i <= digitCount; i++) m.group(i) ?? '0'].join();
      final n = int.tryParse(digits) ?? 0;
      if (n > maxNum) maxNum = n;
    }

    final next = maxNum + 1;
    final nextStr = next.toString().padLeft(digitCount, '0');
    final overflow = nextStr.length > digitCount;
    int digitPos = 0;

    final out = StringBuffer();
    for (final t in tokens) {
      switch (t.token) {
        case 'YYYY':
          out.write(now.year.toString().padLeft(4, '0'));
        case 'YY':
          out.write((now.year % 100).toString().padLeft(2, '0'));
        case '#':
          if (overflow && digitPos == 0) {
            // Write all digits at the first # slot when the number overflows.
            out.write(nextStr);
            digitPos = nextStr.length;
          } else if (digitPos < nextStr.length) {
            out.write(nextStr[digitPos++]);
          }
        case '@':
          out.write('A');
        case '*':
          out.write('0');
        default:
          out.write(t.token);
      }
    }
    return out.toString();
  }

  List<_Token> _tokenize() {
    final tokens = <_Token>[];
    int i = 0;
    while (i < pattern.length) {
      if (i + 4 <= pattern.length && pattern.substring(i, i + 4) == 'YYYY') {
        tokens.add(_Token('YYYY', optional: false));
        i += 4;
      } else if (i + 2 <= pattern.length && pattern.substring(i, i + 2) == 'YY') {
        tokens.add(_Token('YY', optional: false));
        i += 2;
      } else if (pattern[i] == '#' || pattern[i] == '@' || pattern[i] == '*') {
        tokens.add(_Token(pattern[i], optional: false));
        i += 1;
      } else if (i + 2 <= pattern.length && pattern[i + 1] == '?') {
        tokens.add(_Token(pattern[i], optional: true));
        i += 2;
      } else {
        tokens.add(_Token(pattern[i], optional: false));
        i += 1;
      }
    }
    return tokens;
  }
}

class _Token {
  final String token;
  final bool optional;
  const _Token(this.token, {required this.optional});
}
