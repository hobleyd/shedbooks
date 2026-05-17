import 'dart:typed_data';

import 'pdf_text_extractor.dart';

/// A single transaction row parsed from a CBA bank statement PDF.
class CbaTransaction {
  final String date;
  final String description;

  /// Positive cents. Use [isDebit] to determine direction.
  final int amountCents;
  final bool isDebit;
  final int balanceCents;

  const CbaTransaction({
    required this.date,
    required this.description,
    required this.amountCents,
    required this.isDebit,
    required this.balanceCents,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'description': description,
        'amountCents': amountCents,
        'isDebit': isDebit,
        'balanceCents': balanceCents,
      };
}

/// Parsed CBA bank statement data.
class CbaStatementData {
  final String accountNumber;
  final String statementPeriod;
  final int openingBalanceCents;
  final int closingBalanceCents;
  final List<CbaTransaction> transactions;

  const CbaStatementData({
    required this.accountNumber,
    required this.statementPeriod,
    required this.openingBalanceCents,
    required this.closingBalanceCents,
    required this.transactions,
  });

  Map<String, dynamic> toJson() => {
        'accountNumber': accountNumber,
        'statementPeriod': statementPeriod,
        'openingBalanceCents': openingBalanceCents,
        'closingBalanceCents': closingBalanceCents,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };
}

/// Parses a CBA bank statement PDF into structured data.
class CbaStatementParser {
  /// X-coordinate thresholds derived from CBA PDF layout analysis.
  static const double _creditMinX = 400;
  static const double _balanceMinX = 475;

  // CBA PDFs render date components as separate text elements.
  // Transaction rows use 2-element dates ("01", "Apr"); opening/closing
  // balance rows use 3-element dates ("01", "Apr", "2026").
  static final _dayRe = RegExp(r'^\d{1,2}$');
  static final _monthRe = RegExp(
      r'^(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$',
      caseSensitive: false);
  static final _yearRe = RegExp(r'^\d{4}$');

  static const Map<String, String> _monthNums = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
    'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
    'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
  };

  static final _amountRe = RegExp(r'^[\d,]+\.\d{2}$');
  static final _balanceSuffixRe = RegExp(r'^([\d,]+\.\d{2})\s+(?:CR|DR)$');
  static final _openingBalanceRe =
      RegExp(r'opening\s+balance', caseSensitive: false);
  static final _closingBalanceRe =
      RegExp(r'closing\s+balance', caseSensitive: false);

  static final _periodRe = RegExp(
      r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s*[-–]\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})');
  static final _accountRe = RegExp(r'(\d{2}\s+\d{4}\s+\d{8})');

  /// Parses [pdfBytes] and returns structured statement data, or null on failure.
  static CbaStatementData? parse(Uint8List pdfBytes) {
    final elements = PdfTextExtractor.extract(pdfBytes);
    if (elements.isEmpty) return null;

    final allText = elements.map((e) => e.text).join(' ');

    // Extract account number.
    String accountNumber = '';
    final accMatch = _accountRe.firstMatch(allText);
    if (accMatch != null) accountNumber = accMatch.group(1)!;

    // Extract statement period and infer year for transaction dates.
    String statementPeriod = '';
    String? statementYear;
    final periodMatch = _periodRe.firstMatch(allText);
    if (periodMatch != null) {
      statementPeriod = '${periodMatch.group(1)} - ${periodMatch.group(2)}';
      // Extract year from the end date of the period (e.g. "30 Apr 2026" → "2026").
      final endParts = periodMatch.group(2)!.trim().split(RegExp(r'\s+'));
      if (endParts.length >= 3) statementYear = endParts[2];
    }

    // Group elements into rows by y-coordinate proximity (≤3 pt tolerance).
    final rows = _groupByY(elements);

    int? openingBalanceCents;
    int? closingBalanceCents;
    final transactions = <CbaTransaction>[];

    String? pendingDate;
    final pendingDescLines = <String>[];
    int? pendingBalance;

    for (final row in rows) {
      final rowTexts = row.map((e) => e.text).toList();
      final rowFull = rowTexts.join(' ');

      // Skip column-header rows.
      if (rowFull.contains('Debit') &&
          rowFull.contains('Credit') &&
          rowFull.contains('Balance')) continue;

      if (_openingBalanceRe.hasMatch(rowFull)) {
        final cents = _parseBalanceFromRow(row);
        if (cents != null) openingBalanceCents = cents;
        continue;
      }
      if (_closingBalanceRe.hasMatch(rowFull)) {
        final cents = _parseBalanceFromRow(row);
        if (cents != null) closingBalanceCents = cents;
        // Only stop once transactions have been collected — the closing balance
        // also appears in a summary box on page 1 before the transaction table.
        if (transactions.isNotEmpty || pendingDate != null) break;
        continue;
      }

      // Detect whether this row begins a new transaction.
      // CBA PDFs render date components as three separate elements: "01", "Apr", "2026".
      final dateResult = _extractDate(rowTexts, statementYear: statementYear);
      if (dateResult != null) {
        // Flush previous pending transaction.
        if (pendingDate != null && pendingBalance != null) {
          final tx = _buildTransaction(
            pendingDate,
            pendingDescLines,
            pendingBalance!,
            transactions,
            openingBalanceCents,
          );
          if (tx != null) transactions.add(tx);
        }

        final (dateStr, consumed) = dateResult;
        pendingDate = dateStr;
        pendingDescLines.clear();
        pendingBalance = null;

        // Process the rest of the row (after the date elements).
        _extractFromRow(
          row.skip(consumed).toList(),
          pendingDescLines,
          (b) => pendingBalance = b,
        );
      } else if (pendingDate != null) {
        // Continuation row (multi-line description or deferred balance).
        _extractFromRow(row, pendingDescLines, (b) => pendingBalance = b);
      }
    }

    // Flush the last transaction.
    if (pendingDate != null && pendingBalance != null) {
      final tx = _buildTransaction(
        pendingDate,
        pendingDescLines,
        pendingBalance!,
        transactions,
        openingBalanceCents,
      );
      if (tx != null) transactions.add(tx);
    }

    if (openingBalanceCents == null || closingBalanceCents == null) return null;

    return CbaStatementData(
      accountNumber: accountNumber,
      statementPeriod: statementPeriod,
      openingBalanceCents: openingBalanceCents,
      closingBalanceCents: closingBalanceCents,
      transactions: transactions,
    );
  }

  // ── Row grouping ─────────────────────────────────────────────────────────────

  /// Groups text elements into rows by y-coordinate proximity (within 3 pts).
  static List<List<TextElement>> _groupByY(List<TextElement> elements) {
    if (elements.isEmpty) return [];

    final rows = <List<TextElement>>[];
    List<TextElement> current = [elements.first];
    double anchorY = elements.first.y;

    for (final el in elements.skip(1)) {
      if ((el.y - anchorY).abs() <= 3.0) {
        current.add(el);
      } else {
        rows.add(current..sort((a, b) => a.x.compareTo(b.x)));
        current = [el];
        anchorY = el.y;
      }
    }
    if (current.isNotEmpty) rows.add(current..sort((a, b) => a.x.compareTo(b.x)));
    return rows;
  }

  // ── Date detection ───────────────────────────────────────────────────────────

  /// Returns (isoDateString, numberOfElementsConsumed) or null if no date found.
  ///
  /// Handles:
  /// - 3-element: "01", "Apr", "2026"  (opening/closing balance rows)
  /// - 2-element: "01", "Apr"          (regular transaction rows — year inferred)
  /// - 1-element: "01 Apr 2026" or "01 Apr"
  ///
  /// Returns dates in ISO format "YYYY-MM-DD".
  static (String, int)? _extractDate(
    List<String> texts, {
    String? statementYear,
  }) {
    if (texts.isEmpty) return null;

    // Three-element: day month year.
    if (texts.length >= 3 &&
        _dayRe.hasMatch(texts[0]) &&
        _monthRe.hasMatch(texts[1]) &&
        _yearRe.hasMatch(texts[2])) {
      final iso = _toIso(texts[0], texts[1], texts[2]);
      return iso != null ? (iso, 3) : null;
    }

    // Two-element: day month (year from statement period).
    if (texts.length >= 2 &&
        _dayRe.hasMatch(texts[0]) &&
        _monthRe.hasMatch(texts[1])) {
      final year = statementYear ?? DateTime.now().year.toString();
      final iso = _toIso(texts[0], texts[1], year);
      return iso != null ? (iso, 2) : null;
    }

    // Single-element: "01 Apr 2026" or "01 Apr".
    final parts = texts[0].trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 &&
        _dayRe.hasMatch(parts[0]) &&
        _monthRe.hasMatch(parts[1])) {
      final year = parts.length >= 3 && _yearRe.hasMatch(parts[2])
          ? parts[2]
          : (statementYear ?? DateTime.now().year.toString());
      final iso = _toIso(parts[0], parts[1], year);
      return iso != null ? (iso, 1) : null;
    }

    return null;
  }

  /// Converts day/month/year strings to ISO "YYYY-MM-DD", or null if invalid.
  static String? _toIso(String day, String month, String year) {
    final m = _monthNums[month.toLowerCase()];
    if (m == null) return null;
    return '$year-$m-${day.padLeft(2, '0')}';
  }

  // ── Row extraction ───────────────────────────────────────────────────────────

  /// Extracts description words and balance from [rowElements],
  /// skipping amount cells (they're implied by the balance delta).
  static void _extractFromRow(
    List<TextElement> rowElements,
    List<String> descLines,
    void Function(int) onBalance,
  ) {
    bool hasBalance = false;

    for (final el in rowElements) {
      final t = el.text.trim();
      if (t.isEmpty) continue;

      if (el.x >= _balanceMinX) {
        // Balance column.
        final cents = _parseCentsFromElement(t);
        if (cents != null) {
          onBalance(cents);
          hasBalance = true;
        }
      } else if (el.x >= _creditMinX) {
        // Debit/credit amount column — direction inferred from balance delta.
      } else {
        // Description column — skip bare numbers (could be amounts without decimal).
        if (!_amountRe.hasMatch(t)) {
          descLines.add(t);
        }
      }
    }

    // Fallback: if no balance found by x-position, check if last element looks
    // like a balance (e.g. "15,065.46" or "15,065.46 CR").
    if (!hasBalance && rowElements.isNotEmpty) {
      final last = rowElements.last.text.trim();
      final cents = _parseCentsFromElement(last);
      if (cents != null) onBalance(cents);
    }
  }

  /// Parses cents from a balance element that may have a CR/DR suffix.
  static int? _parseCentsFromElement(String t) {
    final m = _balanceSuffixRe.firstMatch(t);
    if (m != null) return _parseCents(m.group(1)!);
    if (_amountRe.hasMatch(t)) return _parseCents(t);
    return null;
  }

  // ── Transaction building ─────────────────────────────────────────────────────

  /// Builds a [CbaTransaction] by comparing [newBalanceCents] to the previous balance.
  static CbaTransaction? _buildTransaction(
    String date,
    List<String> descLines,
    int newBalanceCents,
    List<CbaTransaction> prior,
    int? openingBalanceCents,
  ) {
    final prevBalance =
        prior.isNotEmpty ? prior.last.balanceCents : openingBalanceCents;
    if (prevBalance == null) return null;

    final delta = (newBalanceCents - prevBalance).abs();
    if (delta == 0) return null;

    final isDebit = newBalanceCents < prevBalance;
    final desc = descLines.join(' ').trim();
    if (desc.isEmpty) return null;

    return CbaTransaction(
      date: date,
      description: desc,
      amountCents: delta,
      isDebit: isDebit,
      balanceCents: newBalanceCents,
    );
  }

  // ── Balance parsing ──────────────────────────────────────────────────────────

  /// Extracts balance cents from a row containing "OPENING BALANCE" or "CLOSING BALANCE".
  static int? _parseBalanceFromRow(List<TextElement> row) {
    // Search right-to-left for an amount element.
    for (final el in row.reversed) {
      final t = el.text.trim();
      final m = _balanceSuffixRe.firstMatch(t);
      if (m != null) return _parseCents(m.group(1)!);
      if (_amountRe.hasMatch(t)) return _parseCents(t);
    }
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Parses "1,234.56" into cents (123456).
  static int? _parseCents(String s) {
    final d = double.tryParse(s.replaceAll(',', ''));
    if (d == null) return null;
    return (d * 100).round();
  }
}
