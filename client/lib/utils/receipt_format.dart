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
