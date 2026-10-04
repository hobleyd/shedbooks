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

import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/general_ledger_entry.dart';
import 'package:shedbooks_client/models/pnl_data.dart';
import 'package:shedbooks_client/models/transaction_entry.dart';
import 'package:shedbooks_client/screens/bank_reconciliation_screen.dart';
import 'package:shedbooks_client/utils/split_payments.dart';
import 'package:shedbooks_client/widgets/bank_match_widgets.dart';

TransactionEntry _tx({
  required String id,
  required int total,
  String gl = 'gl1',
  String? group,
  int? lineNo,
  String receipt = 'P-26001',
  String date = '2026-04-01',
  String contactId = 'c1',
  bool bankMatched = false,
}) =>
    TransactionEntry(
      id: id,
      contactId: contactId,
      generalLedgerId: gl,
      receiptNumber: receipt,
      description: '',
      transactionType: 'debit',
      amount: total,
      gstAmount: 0,
      totalAmount: total,
      transactionDate: date,
      bankMatched: bankMatched,
      splitGroupId: group,
      splitLineNo: lineNo,
    );

void main() {
  // A $150 payment split $100 / $50 across two GL codes.
  final splitA = _tx(id: 'a', total: 10000, gl: 'gl1', group: 'g1', lineNo: 1);
  final splitB = _tx(id: 'b', total: 5000, gl: 'gl2', group: 'g1', lineNo: 2);

  group('TransactionEntry.fromJson', () {
    test('reads split fields when present and leaves them null otherwise', () {
      // Arrange
      final Map<String, dynamic> base = {
        'id': 't1',
        'contactId': 'c1',
        'generalLedgerId': 'gl1',
        'receiptNumber': 'P-26001',
        'transactionType': 'debit',
        'amount': 100,
        'gstAmount': 0,
        'totalAmount': 100,
        'transactionDate': '2026-04-01',
      };

      // Act
      final plain = TransactionEntry.fromJson(base);
      final split = TransactionEntry.fromJson(
          {...base, 'splitGroupId': 'g1', 'splitLineNo': 2});

      // Assert
      expect(plain.isSplit, isFalse);
      expect(split.isSplit, isTrue);
      expect(split.splitGroupId, 'g1');
      expect(split.splitLineNo, 2);
      expect(split.copyWith(bankMatched: true).splitGroupId, 'g1');
    });
  });

  group('groupIntoPayments', () {
    test('collapses the lines of a split into one payment at their total', () {
      // Arrange
      final single = _tx(id: 's', total: 700);

      // Act
      final payments = groupIntoPayments([splitB, single, splitA]);

      // Assert
      expect(payments.length, 2);
      expect(payments[0].lines.map((t) => t.id), ['a', 'b']);
      expect(payments[0].totalAmount, 15000);
      expect(payments[0].ids, ['a', 'b']);
      expect(payments[1].lines, [single]);
    });
  });

  group('splitLinesOf', () {
    test('returns every line of the split in line order', () {
      // Act
      final lines = splitLinesOf(splitB, [splitB, _tx(id: 's', total: 1), splitA]);

      // Assert
      expect(lines.map((t) => t.id), ['a', 'b']);
    });

    test('returns just the transaction when it is not split', () {
      // Arrange
      final single = _tx(id: 's', total: 700);

      // Act / Assert
      expect(splitLinesOf(single, [splitA, splitB, single]), [single]);
    });
  });

  group('findMatchingSubset with split transactions', () {
    test('matches a split at the total of its lines', () {
      // Act
      final result = findMatchingSubset([splitA, splitB], 15000);

      // Assert
      expect(result, [splitA, splitB]);
    });

    test('never matches only some lines of a split', () {
      // Act / Assert — 10000 equals line A alone, but a split is one payment.
      expect(findMatchingSubset([splitA, splitB], 10000), isNull);
    });
  });

  group('disambiguateByContactName with split transactions', () {
    test('treats the lines of one split as a single candidate', () {
      // Arrange
      final other = _tx(id: 'o', total: 15000, contactId: 'c2');

      // Act
      final result = disambiguateByContactName(
        [splitA, splitB, other],
        'Transfer to Acme',
        {'c1': 'Acme', 'c2': 'Bob'},
      );

      // Assert
      expect(result, [splitA, splitB]);
    });
  });

  group('matchRecDebitRow with split transactions', () {
    RecRowMatchResult match(List<TransactionEntry> all, int amountCents) =>
        matchRecDebitRow(
          allTransactions: all,
          reservedIds: {},
          selectedBankAccountId: null,
          parsedReceipts: const [],
          description: 'Direct debit',
          amountCents: amountCents,
          processDate: '2026-04-01',
          contactNames: const {'c1': 'Acme'},
          alreadyImportedByKey: false,
        );

    test('auto-matches every line when the bank amount equals the split total', () {
      // Act
      final result = match([splitA, splitB], 15000);

      // Assert
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, [splitA, splitB]);
    });

    test('does not match a bank amount that equals a single line of the split', () {
      // Act
      final result = match([splitA, splitB], 10000);

      // Assert
      expect(result.status, BankMatchStatus.unmatched);
      expect(result.matched, isEmpty);
    });
  });

  group('PnLData.compute with split transactions', () {
    test('reports each line of a split under its own GL account', () {
      // Arrange
      const gl1 = GeneralLedgerEntry(
        id: 'gl1',
        label: 'Materials',
        description: 'Materials',
        gstApplicable: true,
        direction: GlDirection.moneyOut,
      );
      const gl2 = GeneralLedgerEntry(
        id: 'gl2',
        label: 'Tools',
        description: 'Tools',
        gstApplicable: true,
        direction: GlDirection.moneyOut,
      );

      // Act
      final pnl = PnLData.compute(
        allTransactions: [splitA, splitB],
        glMap: const {'gl1': gl1, 'gl2': gl2},
        filter: (_) => true,
      );

      // Assert
      expect(pnl.totalExpenses, 15000);
      expect({for (final l in pnl.expenseLines) l.gl.id: l.totalCents},
          {'gl1': 10000, 'gl2': 5000});
    });
  });
}
