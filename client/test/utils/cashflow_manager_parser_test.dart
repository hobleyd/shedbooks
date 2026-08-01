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

import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/general_ledger_entry.dart';
import 'package:shedbooks_client/utils/cashflow_manager_parser.dart';

// A small but structurally faithful sample of a real CashFlow Manager
// "Transaction Listing" export: multi-line narrative before the GL code
// appears, a transaction split across several GL codes, and — the tricky
// real-world case — an interest-income row physically inside the "Money
// Out" section using the Money In column layout (gross lands in the last
// "Bank Deposits"-shaped column rather than the "Total" column).
const _sampleCsv = '''
Transaction Listing
Test Org
Report Period: 01/01/2025 to 31/12/2025
Account(s) in this report: Test

Money In
Date,Ref,Details,Code,Column Name,Quantity,Amount,GST Output Tax,Receipts Not Banked,Bank Deposits

06/02/25,2005,Membership fees
Grilanc   2005   6/2/25,4-4080,Membership Fees,,240.00,,,240.00

Total Money In,,,,,,240.00,0.00,0.00,240.00

Money Out
Date,Ref,Details,Code,Column Name,Quantity,Amount,GST Input Tax,Total,

06/02/25,P1,Evan Simpson Purchase of parts,6-0170,Building repair and maintenance expenses,,152.00,15.20,167.20,,

13/05/25,P201,Multiple payments,6-0130,Workshop Consumables,,68.05,6.80,184.85,,
,,,6-0170,Building repair and maintenance expenses,,80.00,8.00,,,
,,,6-0170,Cleaning Expenses - General,,20.00,2.00,,,

01/01/25,N/A,CBA 4-5020 Interest Income,4-5020,Interest Received,,1.61,,,1.61

Total Money Out,,,,,,300.05,32.00,332.05,,
''';

void main() {
  group('parseCashflowManagerCsv', () {
    late List<CashflowManagerRow> rows;

    setUp(() {
      rows = parseCashflowManagerCsv(_sampleCsv);
    });

    test('reconstructs one row per GL split', () {
      expect(rows.length, 6);
    });

    test('reconciles grand totals across every row (not per printed section)', () {
      final totalAmount = rows.fold<int>(0, (s, r) => s + r.amountCents);
      final totalGst = rows.fold<int>(0, (s, r) => s + r.gstCents);
      expect(totalAmount, 56166); // $561.66
      expect(totalGst, 3200); // $32.00
    });

    test('joins a multi-line narrative that precedes the GL code', () {
      final row = rows.firstWhere((r) => r.externalCode == '4-4080');
      expect(row.date, '2025-02-06');
      expect(row.description, contains('Membership fees'));
      expect(row.description, contains('Grilanc'));
      expect(row.amountCents, 24000);
      expect(row.gstCents, 0);
    });

    test('splits one bank transaction across multiple GL codes, sharing date/narrative', () {
      final splits = rows.where((r) => r.ref == 'P201').toList();
      expect(splits.length, 3);
      expect(splits.every((r) => r.date == '2025-05-13'), isTrue);
      expect(splits.every((r) => r.description == 'Multiple payments'), isTrue);
      expect(splits.map((r) => r.externalCode), ['6-0130', '6-0170', '6-0170']);
      expect(splits.map((r) => r.amountCents), [6805, 8000, 2000]);
      expect(splits.map((r) => r.gstCents), [680, 800, 200]);
    });

    test('guesses credit/debit from the money column actually populated, not the section', () {
      final membershipRow = rows.firstWhere((r) => r.externalCode == '4-4080');
      expect(membershipRow.guessedCredit, isTrue);
      expect(membershipRow.guessedDirection, GlDirection.moneyIn);

      final repairRow = rows.firstWhere((r) => r.externalCode == '6-0170' && r.ref == 'P1');
      expect(repairRow.guessedCredit, isFalse);
      expect(repairRow.guessedDirection, GlDirection.moneyOut);

      // Interest row sits inside "Money Out" (before "Total Money Out") but
      // uses the Money In column layout — must be detected as credit from
      // its own columns, not from which printed section it falls under.
      final interestRow = rows.firstWhere((r) => r.externalCode == '4-5020');
      expect(interestRow.guessedCredit, isTrue);
    });

    test('splits with no column-level signal fall back to the section as a tiebreaker', () {
      final splits = rows.where((r) => r.ref == 'P201').toList();
      expect(splits.every((r) => r.guessedCredit == false), isTrue);
    });

    test('ignores preamble, section headers, and total rows', () {
      expect(rows.any((r) => r.externalCode.isEmpty), isFalse);
      expect(rows.any((r) => r.date.isEmpty), isFalse);
    });
  });

  group('decodeCashflowManagerCsvBytes', () {
    test('passes plain UTF-8 content through unchanged', () {
      const text = 'Date,Ref,Details\n06/02/25,2005,Membership fees\n';
      final decoded = decodeCashflowManagerCsvBytes(utf8.encode(text));
      expect(decoded, text);
    });

    test('strips a UTF-8 BOM', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Date,Ref\n')];
      expect(decodeCashflowManagerCsvBytes(bytes), 'Date,Ref\n');
    });

    test('reverses quoted-printable soft line breaks and hex escapes', () {
      // "Cash =\r\nFloat" is how a QP encoder wraps "Cash Float" mid-line;
      // "=20" is an escaped space. Decoding should undo both.
      final bytes = utf8.encode('1-1150 Cash =\r\nFloat 1-1170=20Term Deposits');
      expect(
        decodeCashflowManagerCsvBytes(bytes),
        '1-1150 Cash Float 1-1170 Term Deposits',
      );
    });

    test('leaves an ordinary CSV containing a bare "=" untouched', () {
      const text = 'Details,Code\n"A = B",4-1000\n';
      expect(decodeCashflowManagerCsvBytes(utf8.encode(text)), text);
    });
  });

  group('fuzzyMatchGlAccount', () {
    final accounts = [
      const GeneralLedgerEntry(
        id: 'gl-1',
        label: 'Membership',
        description: 'Membership Fees',
        gstApplicable: false,
        direction: GlDirection.moneyIn,
      ),
      const GeneralLedgerEntry(
        id: 'gl-2',
        label: 'Repairs',
        description: 'Building repair and maintenance expenses',
        gstApplicable: true,
        direction: GlDirection.moneyOut,
      ),
    ];

    test('returns full confidence on an exact description match', () {
      final match = fuzzyMatchGlAccount('Membership Fees', accounts);
      expect(match.glId, 'gl-1');
      expect(match.confidence, 1.0);
      expect(match.isConfident, isTrue);
    });

    test('returns a lower-confidence fuzzy match for a close description', () {
      final match = fuzzyMatchGlAccount('Building repairs and maintenance', accounts);
      expect(match.glId, 'gl-2');
      expect(match.confidence, greaterThan(0.3));
      expect(match.confidence, lessThan(1.0));
    });

    test('returns no match for an unrelated description', () {
      final match = fuzzyMatchGlAccount('Zzyzx Quantum Widgets', accounts);
      expect(match.glId, isNull);
      expect(match.confidence, 0.0);
    });

    test('direction filter still finds a match within the filtered subset', () {
      final match = fuzzyMatchGlAccount(
        'Building repairs and maintenance',
        accounts,
        direction: GlDirection.moneyOut,
      );
      expect(match.glId, 'gl-2');
    });

    test('direction filter excludes an otherwise exact match from the other direction', () {
      // "Membership Fees" is a Money In account only — asking for Money
      // Out must not match it, even though the description is exact.
      final match = fuzzyMatchGlAccount(
        'Membership Fees',
        accounts,
        direction: GlDirection.moneyOut,
      );
      expect(match.glId, isNull);
      expect(match.confidence, 0.0);
    });
  });
}
