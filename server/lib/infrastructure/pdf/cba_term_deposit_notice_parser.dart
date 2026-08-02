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

import 'dart:typed_data';

import 'cba_statement_parser.dart';
import 'pdf_text_extractor.dart';

/// Parses a CBA "Confirmation of Holding Facility Notice" PDF — the document
/// CBA sends when a Term Deposit matures and its balance (plus the interest
/// earned) moves into the holding facility pending reinvestment/withdrawal.
///
/// Unlike ordinary CBA statements this notice has no transaction table: it
/// states a single "Interest paid this financial year" figure and the
/// resulting "Investment balance". Those are used to synthesize a
/// single-transaction [CbaStatementData] (opening = investment balance minus
/// interest, closing = investment balance) so the notice flows through the
/// same reconciliation UI as regular statements.
class CbaTermDepositNoticeParser {
  static final _titleRe = RegExp(
      r'Confirmation\s+of\s+Holding\s+Facility\s+Notice',
      caseSensitive: false);
  static final _tdNumberRe = RegExp(
      r'Term\s+Deposit\s+number\s+(\d{2}\s+\d{4}\s+\d{8})',
      caseSensitive: false);
  static final _interestPaidRe = RegExp(
      r'Interest\s+paid\s+this\s+financial\s+year\s+\$?([\d,]+\.\d{2})',
      caseSensitive: false);
  static final _investmentBalanceRe = RegExp(
      r'Investment\s+balance\s+\$?([\d,]+\.\d{2})',
      caseSensitive: false);
  static final _placedDateRe = RegExp(
      r'Placed\s+in\s+holding\s+facility\s+on\s+(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})',
      caseSensitive: false);
  static final _maturedDateRe = RegExp(
      r'Term\s+Deposit\s+matured\s+on\s+(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})',
      caseSensitive: false);

  static const Map<String, String> _monthNums = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
    'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
    'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
  };

  /// Returns parsed data if [pdfBytes] look like a Term Deposit holding
  /// facility notice, or null if the document doesn't match this format.
  static CbaStatementData? parse(Uint8List pdfBytes) {
    final elements = PdfTextExtractor.extract(pdfBytes);
    if (elements.isEmpty) return null;

    final allText = elements.map((e) => e.text).join(' ');
    if (!_titleRe.hasMatch(allText)) return null;

    final interestMatch = _interestPaidRe.firstMatch(allText);
    final balanceMatch = _investmentBalanceRe.firstMatch(allText);
    if (interestMatch == null || balanceMatch == null) return null;

    final interestCents = _parseCents(interestMatch.group(1)!);
    final closingCents = _parseCents(balanceMatch.group(1)!);
    if (interestCents == null || closingCents == null) return null;

    final dateMatch =
        _placedDateRe.firstMatch(allText) ?? _maturedDateRe.firstMatch(allText);
    if (dateMatch == null) return null;
    final iso =
        _toIso(dateMatch.group(1)!, dateMatch.group(2)!, dateMatch.group(3)!);
    if (iso == null) return null;
    // The notice spells months out in full ("26 July 2026"), but the client's
    // statement-period parser only recognises 3-letter abbreviations (the
    // form CBA's ordinary statements use) — normalize so month locking works.
    final monthAbbrev = _monthAbbrev(dateMatch.group(2)!);
    if (monthAbbrev == null) return null;
    final periodStr = '${dateMatch.group(1)} $monthAbbrev ${dateMatch.group(3)}';

    String accountNumber = '';
    final accMatch = _tdNumberRe.firstMatch(allText);
    if (accMatch != null) accountNumber = accMatch.group(1)!;

    final tx = CbaTransaction(
      date: iso,
      description: 'Term Deposit interest',
      amountCents: interestCents,
      isDebit: false,
      balanceCents: closingCents,
    );

    return CbaStatementData(
      accountNumber: accountNumber,
      statementPeriod: '$periodStr - $periodStr',
      openingBalanceCents: closingCents - interestCents,
      closingBalanceCents: closingCents,
      transactions: [tx],
    );
  }

  /// Converts day/month/year strings to ISO "YYYY-MM-DD", or null if invalid.
  static String? _toIso(String day, String month, String year) {
    final m = _monthNums[month.toLowerCase().substring(0, 3)];
    if (m == null) return null;
    return '$year-$m-${day.padLeft(2, '0')}';
  }

  /// Converts a full or abbreviated month name to CBA's standard 3-letter,
  /// title-case abbreviation (e.g. "July" or "jul" -> "Jul").
  static String? _monthAbbrev(String month) {
    if (month.length < 3) return null;
    final key = month.toLowerCase().substring(0, 3);
    if (!_monthNums.containsKey(key)) return null;
    return key[0].toUpperCase() + key.substring(1);
  }

  /// Parses "1,234.56" into cents (123456).
  static int? _parseCents(String s) {
    final d = double.tryParse(s.replaceAll(',', ''));
    if (d == null) return null;
    return (d * 100).round();
  }
}
