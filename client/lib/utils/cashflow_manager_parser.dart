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

import 'dart:convert';

import '../models/general_ledger_entry.dart';

/// One reconstructed transaction line from a CashFlow Manager "Transaction
/// Listing" report.
///
/// CashFlow Manager's CSV export is not a normal one-row-per-transaction
/// file: a transaction's narrative can wrap across several physical lines
/// before its GL code and amount appear, and a single bank transaction can
/// be split across several GL codes (each its own physical line, sharing
/// the same date/narrative). [parseCashflowManagerCsv] reconstructs one
/// [CashflowManagerRow] per GL split.
class CashflowManagerRow {
  /// 'YYYY-MM-DD'.
  final String date;
  final String ref;
  final String description;

  /// CashFlow Manager's own account code, e.g. "4-4080". Used as the
  /// session-reentrant key for GL matching — the same code should not be
  /// re-prompted twice.
  final String externalCode;

  /// CashFlow Manager's account description, e.g. "Membership Fees".
  final String externalName;

  /// Excl. GST, in cents.
  final int amountCents;
  final int gstCents;

  /// Best-effort guess at whether this row is income (Money In) based on
  /// which trailing column the gross amount lands in — the report's own
  /// section markers are not reliable on their own (adjusting entries such
  /// as interest and internal transfers appear inside the "wrong" section
  /// in practice). Used to restrict GL matching and the "Match GL Codes"
  /// dropdown to accounts of the matching direction; the transaction
  /// actually saved still takes its direction from the GL account the user
  /// confirms, not from this flag directly.
  final bool guessedCredit;

  const CashflowManagerRow({
    required this.date,
    required this.ref,
    required this.description,
    required this.externalCode,
    required this.externalName,
    required this.amountCents,
    required this.gstCents,
    required this.guessedCredit,
  });

  int get grossCents => amountCents + gstCents;

  GlDirection get guessedDirection =>
      guessedCredit ? GlDirection.moneyIn : GlDirection.moneyOut;
}

enum _Section { none, moneyIn, moneyOut }

/// Parses a CashFlow Manager "Transaction Listing" CSV export into
/// individual GL-split rows. Pure function — no I/O, no GL matching.
List<CashflowManagerRow> parseCashflowManagerCsv(String content) {
  final lines =
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  final rows = <CashflowManagerRow>[];
  _Section section = _Section.none;
  String currentDate = '';
  String currentRef = '';
  String currentNarrative = '';

  void processSegment(List<String> seg) {
    final splitIndex = _findSplitIndex(seg);
    if (splitIndex == null) {
      final text = seg.where((s) => s.isNotEmpty).join(' ');
      if (text.isNotEmpty) {
        currentNarrative =
            currentNarrative.isEmpty ? text : '$currentNarrative $text';
      }
      return;
    }

    final prefixText = seg.sublist(0, splitIndex).where((s) => s.isNotEmpty).join(' ');
    if (prefixText.isNotEmpty) {
      currentNarrative = currentNarrative.isEmpty
          ? prefixText
          : '$currentNarrative $prefixText';
    }

    final code = seg[splitIndex];
    final name = seg[splitIndex + 1];
    final amountCents = _parseMoneyCentsOrNull(seg[splitIndex + 3]) ?? 0;
    final gstCents = splitIndex + 4 < seg.length
        ? (_parseMoneyCentsOrNull(seg[splitIndex + 4]) ?? 0)
        : 0;
    if (amountCents == 0 && gstCents == 0) return;

    final gross = amountCents + gstCents;
    final totalCents =
        splitIndex + 5 < seg.length ? _parseMoneyCentsOrNull(seg[splitIndex + 5]) : null;
    final bankDepositsCents =
        splitIndex + 6 < seg.length ? _parseMoneyCentsOrNull(seg[splitIndex + 6]) : null;

    final bool guessedCredit;
    if (bankDepositsCents != null && bankDepositsCents == gross) {
      guessedCredit = true;
    } else if (totalCents != null && totalCents == gross) {
      guessedCredit = false;
    } else {
      guessedCredit = section == _Section.moneyIn;
    }

    rows.add(CashflowManagerRow(
      date: currentDate,
      ref: currentRef,
      description: currentNarrative,
      externalCode: code,
      externalName: name,
      amountCents: amountCents,
      gstCents: gstCents,
      guessedCredit: guessedCredit,
    ));
  }

  for (final rawLine in lines) {
    if (rawLine.trim().isEmpty) continue;
    final fields = _parseCsvLine(rawLine);
    if (fields.every((f) => f.isEmpty)) continue;

    final firstLower = fields[0].toLowerCase();

    if (firstLower == 'money in') {
      section = _Section.moneyIn;
      currentNarrative = '';
      continue;
    }
    if (firstLower == 'money out') {
      section = _Section.moneyOut;
      currentNarrative = '';
      continue;
    }
    if (firstLower.startsWith('total money')) {
      section = _Section.none;
      currentNarrative = '';
      continue;
    }
    if (firstLower == 'date') continue; // column header row
    if (section == _Section.none) continue; // preamble / postamble text

    if (_looksLikeDate(fields[0])) {
      currentDate = _normalizeDate(fields[0]);
      currentRef = fields.length > 1 ? fields[1] : '';
      currentNarrative = '';
      processSegment(fields.length > 2 ? fields.sublist(2) : const []);
    } else {
      processSegment(fields);
    }
  }

  return rows;
}

/// Finds the index of the GL code field within [seg], anchored on the
/// "Amount" column three positions later (Code, Column Name, Quantity,
/// Amount is the fixed layout used by both the Money In and Money Out
/// sections). Returns null when no such column is present, meaning [seg]
/// is pure narrative continuation text.
int? _findSplitIndex(List<String> seg) {
  for (int i = 0; i + 3 < seg.length; i++) {
    if (seg[i].isEmpty) continue;
    if (seg[i + 1].isEmpty) continue;
    if (_parseMoneyCentsOrNull(seg[i + 3]) != null) return i;
  }
  return null;
}

bool _looksLikeDate(String s) => RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}$').hasMatch(s);

String _normalizeDate(String s) {
  final parts = s.split('/');
  final day = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  int year = int.parse(parts[2]);
  if (year < 100) year += 2000;
  return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

final _moneyPattern = RegExp(r'^-?\d+(\.\d{1,2})?$');

int? _parseMoneyCentsOrNull(String raw) {
  final cleaned = raw.replaceAll(',', '').replaceAll(r'$', '');
  if (!_moneyPattern.hasMatch(cleaned)) return null;
  final value = double.tryParse(cleaned);
  if (value == null) return null;
  return (value * 100).round();
}

/// Splits one CSV line into fields, trimming whitespace and honouring
/// double-quoted fields. Trailing commas produce a trailing empty field
/// (standard CSV semantics), which the column-position logic above relies
/// on to tell the Money In and Money Out row layouts apart.
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(ch);
      }
    } else if (ch == '"' && buf.isEmpty) {
      inQuotes = true;
    } else if (ch == ',') {
      fields.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  fields.add(buf.toString().trim());
  return fields;
}

// ── Quoted-printable transport decoding ─────────────────────────────────────

/// Decodes raw file [bytes] into text, first reversing quoted-printable
/// transport encoding if the file looks wrapped in it.
///
/// Some exports of this report (e.g. saved from an emailed copy) arrive as
/// quoted-printable text — literal `=XX` hex escapes and `=` soft line
/// breaks — rather than plain UTF-8. A genuine CSV essentially never ends a
/// line with a bare `=`, so the presence of a soft break is used as the
/// signal to decode; otherwise the bytes are treated as UTF-8 directly.
String decodeCashflowManagerCsvBytes(List<int> bytes) {
  final source =
      _looksQuotedPrintable(bytes) ? _decodeQuotedPrintableBytes(bytes) : bytes;
  var text = utf8.decode(source, allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  return text;
}

bool _looksQuotedPrintable(List<int> bytes) {
  for (int i = 0; i + 1 < bytes.length; i++) {
    if (bytes[i] != 0x3D) continue; // '='
    if (bytes[i + 1] == 0x0A) return true; // '=\n'
    if (i + 2 < bytes.length && bytes[i + 1] == 0x0D && bytes[i + 2] == 0x0A) {
      return true; // '=\r\n'
    }
  }
  return false;
}

List<int> _decodeQuotedPrintableBytes(List<int> bytes) {
  final out = <int>[];
  int i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b == 0x3D && i + 1 < bytes.length) {
      if (bytes[i + 1] == 0x0A) {
        i += 2;
        continue;
      }
      if (i + 2 < bytes.length && bytes[i + 1] == 0x0D && bytes[i + 2] == 0x0A) {
        i += 3;
        continue;
      }
      if (i + 2 < bytes.length) {
        final hex = String.fromCharCodes(bytes.sublist(i + 1, i + 3));
        final value = int.tryParse(hex, radix: 16);
        if (value != null) {
          out.add(value);
          i += 3;
          continue;
        }
      }
    }
    out.add(b);
    i++;
  }
  return out;
}

// ── GL matching ──────────────────────────────────────────────────────────────

/// Result of matching a CashFlow Manager external GL description against
/// this entity's chart of accounts.
class GlMatch {
  final String? glId;

  /// 0.0-1.0; 1.0 = exact description match.
  final double confidence;

  const GlMatch(this.glId, this.confidence);

  bool get isConfident => confidence >= 0.85;
}

/// Finds the closest-matching GL account for [externalName] (CashFlow
/// Manager's "Column Name", e.g. "Membership Fees") among the accounts in
/// [accounts]. When [direction] is given, only accounts of that direction
/// are considered — callers should pass the row's [CashflowManagerRow.
/// guessedDirection] so a code from the Money In side of the export can't
/// match a Money Out account and vice versa.
GlMatch fuzzyMatchGlAccount(
  String externalName,
  List<GeneralLedgerEntry> accounts, {
  GlDirection? direction,
}) {
  final name = externalName.trim().toLowerCase();
  final candidates = direction == null
      ? accounts
      : accounts.where((g) => g.direction == direction).toList();
  if (name.isEmpty || candidates.isEmpty) return const GlMatch(null, 0.0);

  for (final gl in candidates) {
    if (gl.description.trim().toLowerCase() == name) return GlMatch(gl.id, 1.0);
  }

  String? bestId;
  double bestScore = 0.0;
  for (final gl in candidates) {
    // Path-building still walks the full (unfiltered) account list so a
    // parent of a different direction — should one ever exist — doesn't
    // truncate the displayed path.
    final targets = <String>{
      gl.description.toLowerCase(),
      buildGlPath(accounts, gl.id).toLowerCase(),
    };
    for (final target in targets) {
      final score = _diceSimilarity(name, target);
      if (score > bestScore) {
        bestScore = score;
        bestId = gl.id;
      }
    }
  }

  if (bestScore < 0.3) return const GlMatch(null, 0.0);
  return GlMatch(bestId, bestScore);
}

/// Dice coefficient bigram similarity between two strings.
double _diceSimilarity(String a, String b) {
  if (a == b) return 1.0;
  if (a.length < 2 || b.length < 2) return 0.0;

  Set<String> bigrams(String s) {
    final set = <String>{};
    for (int i = 0; i < s.length - 1; i++) {
      set.add(s.substring(i, i + 2));
    }
    return set;
  }

  final ba = bigrams(a);
  final bb = bigrams(b);
  final intersection = ba.intersection(bb).length;
  return (2.0 * intersection) / (ba.length + bb.length);
}
