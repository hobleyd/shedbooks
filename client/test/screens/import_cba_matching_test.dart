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
import 'package:shedbooks_client/models/transaction_entry.dart';
import 'package:shedbooks_client/screens/import_cba_screen.dart';
import 'package:shedbooks_client/widgets/bank_match_widgets.dart';

TransactionEntry _tx({
  required String id,
  String receipt = 'P-26001',
  String? paymentReference,
  int total = 5000,
  String type = 'debit',
  String date = '2026-04-01',
  String contactId = 'c1',
  bool bankMatched = false,
  String? abaBatchName,
  String? bankAccountId,
}) =>
    TransactionEntry(
      id: id,
      contactId: contactId,
      generalLedgerId: 'gl1',
      receiptNumber: receipt,
      paymentReference: paymentReference,
      description: '',
      transactionType: type,
      amount: total,
      gstAmount: 0,
      totalAmount: total,
      transactionDate: date,
      bankMatched: bankMatched,
      abaBatchName: abaBatchName,
      bankAccountId: bankAccountId,
    );

CbaRowMatchResult _debit({
  required List<TransactionEntry> allTransactions,
  Set<String> reservedIds = const {},
  String? selectedBankAccountId,
  List<String> parsedReceipts = const [],
  String description = '',
  int amountCents = 5000,
  String processDate = '2026-04-01',
  Map<String, String> contactNames = const {},
}) =>
    matchCbaDebitRow(
      allTransactions: allTransactions,
      reservedIds: reservedIds,
      selectedBankAccountId: selectedBankAccountId,
      parsedReceipts: parsedReceipts,
      description: description,
      amountCents: amountCents,
      processDate: processDate,
      contactNames: contactNames,
    );

CbaRowMatchResult _credit({
  required List<TransactionEntry> allTransactions,
  Set<String> reservedIds = const {},
  String? selectedBankAccountId,
  List<String> parsedReceipts = const [],
  String description = '',
  int amountCents = 5000,
  String processDate = '2026-04-01',
  Map<String, String> contactNames = const {},
}) =>
    matchCbaCreditRow(
      allTransactions: allTransactions,
      reservedIds: reservedIds,
      selectedBankAccountId: selectedBankAccountId,
      parsedReceipts: parsedReceipts,
      description: description,
      amountCents: amountCents,
      processDate: processDate,
      contactNames: contactNames,
    );

void main() {
  group('matchCbaDebitRow — receipt number matching', () {
    test('matches by receipt number recognised in the statement text', () {
      final txn = _tx(id: '1', receipt: 'P-26062');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
    });

    test('unmatched when the recognised receipt has no corresponding transaction', () {
      final result = _debit(
        allTransactions: [],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
      );
      expect(result.status, BankMatchStatus.unmatched);
      expect(result.matched, isEmpty);
    });

    test('alreadyImported when the recognised receipt is already bank-matched for the full amount', () {
      final txn = _tx(id: '1', receipt: 'P-26062', total: 5000, bankMatched: true);
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });

    test('unmatched when an already bank-matched receipt does not sum to the bank amount', () {
      final txn = _tx(id: '1', receipt: 'P-26062', total: 5000, bankMatched: true);
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
        amountCents: 9999, // doesn't match the matched txn's total
      );
      expect(result.status, BankMatchStatus.unmatched);
    });

    test('amountMismatch when candidates are found but none sum to the bank amount', () {
      final txn = _tx(id: '1', receipt: 'P-26062', total: 4000);
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.amountMismatch);
      expect(result.matched, equals([txn]));
    });

    test('multi-line items: selects the subset that sums exactly to the bank amount', () {
      final a = _tx(id: '1', receipt: 'P-26062', total: 3000);
      final b = _tx(id: '2', receipt: 'P-26062', total: 2000);
      final result = _debit(
        allTransactions: [a, b],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched.toSet(), equals({a, b}));
    });

    test('reserved ids are excluded even when the receipt matches', () {
      final txn = _tx(id: '1', receipt: 'P-26062');
      final result = _debit(
        allTransactions: [txn],
        reservedIds: {'1'},
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
      );
      expect(result.status, BankMatchStatus.unmatched);
    });

    test('a bank account filter excludes transactions recorded against a different account', () {
      final txn = _tx(id: '1', receipt: 'P-26062', bankAccountId: 'acct-A');
      final result = _debit(
        allTransactions: [txn],
        selectedBankAccountId: 'acct-B',
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
      );
      expect(result.status, BankMatchStatus.unmatched);
    });

    test('credit transactions never match a debit row even by receipt number', () {
      final txn = _tx(id: '1', receipt: 'P-26062', type: 'credit');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
      );
      expect(result.status, BankMatchStatus.unmatched);
    });
  });

  group('matchCbaDebitRow — Payment Reference matching', () {
    test('matches via Payment Reference when no receipt-number format matches the text', () {
      final txn = _tx(id: '1', receipt: 'P-26062', paymentReference: 'INV-9876-REF');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [], // format didn't recognise anything
        description: 'EFT INV-9876-REF ACME PTY LTD',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
    });

    test('a Payment Reference match is treated as recognised — falls to unmatched, not the date+amount fuzzy fallback', () {
      // Regression check for the bug this feature was built to fix: an
      // unrelated same-date/same-amount transaction must NOT be picked up
      // just because the recognised Payment Reference didn't resolve to an
      // eligible candidate (e.g. it's on a different bank account).
      final referenced = _tx(
        id: '1',
        receipt: 'P-26062',
        paymentReference: 'INV-9876-REF',
        bankAccountId: 'acct-A',
        total: 5000,
      );
      final decoy = _tx(id: '2', receipt: 'P-99999', total: 5000); // same date+amount
      final result = _debit(
        allTransactions: [referenced, decoy],
        selectedBankAccountId: 'acct-B', // referenced txn is on a different account
        parsedReceipts: const [],
        description: 'EFT INV-9876-REF ACME PTY LTD',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.unmatched);
      expect(result.matched, isEmpty);
    });

    test('alreadyImported when the Payment Reference transaction is already bank-matched for the full amount', () {
      final txn = _tx(
        id: '1',
        receipt: 'P-26062',
        paymentReference: 'INV-9876-REF',
        total: 5000,
        bankMatched: true,
      );
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'EFT INV-9876-REF ACME PTY LTD',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });

    test('a recognised receipt number and a recognised payment reference are both candidates', () {
      // Neither alone sums to the bank amount — only combining the
      // receipt-recognised transaction with the payment-reference-recognised
      // one does, proving both detection paths feed the same candidate pool.
      final byReceipt = _tx(id: '1', receipt: 'P-26062', total: 3000);
      final byRef = _tx(id: '2', receipt: 'P-99999', paymentReference: 'RENT-AUG', total: 2000);
      final result = _debit(
        allTransactions: [byReceipt, byRef],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062 RENT-AUG',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched.toSet(), equals({byReceipt, byRef}));
    });

    test('a Payment Reference on a credit transaction is never considered (Money-Out only in practice)', () {
      final txn = _tx(id: '1', receipt: 'P-26062', paymentReference: 'INV-9876-REF', type: 'credit');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'EFT INV-9876-REF ACME PTY LTD',
      );
      // referencedTxns is non-empty (paymentReference matched), but the
      // transactionType filter excludes it from `found` — falls through to
      // "recognised but unresolved" → unmatched, not autoMatched.
      expect(result.status, BankMatchStatus.unmatched);
    });
  });

  group('matchCbaDebitRow — ABA batch name matching', () {
    test('matches by WMS batch name when no receipt or payment reference is recognised', () {
      final a = _tx(id: '1', receipt: 'P-26001', total: 3000, abaBatchName: 'WMS260830001');
      final b = _tx(id: '2', receipt: 'P-26002', total: 2000, abaBatchName: 'WMS260830001');
      final result = _debit(
        allTransactions: [a, b],
        parsedReceipts: const [],
        description: 'DIRECT DEBIT WMS260830001',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched.toSet(), equals({a, b}));
    });
  });

  group('matchCbaDebitRow — date + amount fallback', () {
    test('a single unmatched candidate on date+amount auto-matches', () {
      final txn = _tx(id: '1', receipt: 'P-26001', total: 5000, date: '2026-04-01');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
    });

    test('multiple candidates are disambiguated by contact name in the description', () {
      final a = _tx(id: '1', receipt: 'P-26001', total: 5000, contactId: 'c1');
      final b = _tx(id: '2', receipt: 'P-26002', total: 5000, contactId: 'c2');
      final result = _debit(
        allTransactions: [a, b],
        parsedReceipts: const [],
        description: 'PAYMENT TO ACME PTY LTD',
        amountCents: 5000,
        contactNames: {'c1': 'Acme Pty Ltd', 'c2': 'Other Co'},
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([a]));
    });

    test('multiple candidates that cannot be disambiguated need manual selection', () {
      final a = _tx(id: '1', receipt: 'P-26001', total: 5000);
      final b = _tx(id: '2', receipt: 'P-26002', total: 5000);
      final result = _debit(
        allTransactions: [a, b],
        parsedReceipts: const [],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.needsSelection);
      expect(result.matched.toSet(), equals({a, b}));
    });

    test('no candidates at all is unmatched', () {
      final result = _debit(
        allTransactions: [],
        parsedReceipts: const [],
        description: 'SOME OTHER TEXT',
      );
      expect(result.status, BankMatchStatus.unmatched);
    });

    test('no unmatched candidates but an already-matched subset sums to the amount is alreadyImported', () {
      final txn = _tx(
        id: '1',
        receipt: 'P-26001',
        total: 5000,
        date: '2026-04-01',
        bankMatched: true,
      );
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });
  });

  group('matchCbaCreditRow', () {
    test('matches by receipt number', () {
      final txn = _tx(id: '1', receipt: 'P-26001', type: 'credit');
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: ['P-26001'],
        description: 'EFT P26001',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
    });

    test('alreadyImported when the receipt is already bank-matched for the full amount', () {
      final txn = _tx(id: '1', receipt: 'P-26001', type: 'credit', total: 5000, bankMatched: true);
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: ['P-26001'],
        description: 'EFT P26001',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });

    test('falls back to date + amount when no receipt is recognised', () {
      final txn = _tx(id: '1', receipt: 'P-26001', type: 'credit', total: 5000, date: '2026-04-01');
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'DEPOSIT',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
    });

    test('a manually matched transaction with a mismatched reference is still '
        'recognised as alreadyImported once its date has been stamped to the '
        "bank row's clearing date", () {
      // Regression for: a manual match with a wrong/mismatched invoice
      // reference left the transaction invisible to every re-detection path
      // (receipt lookup fails by construction, and the date+amount fallback
      // also failed because manual matching never used to update the
      // transaction's date). Bank-match now stamps the row's processDate
      // onto the transaction, which lets this fallback recognise it.
      final txn = _tx(
        id: '1',
        receipt: 'WRONG-REF',
        type: 'credit',
        total: 5000,
        date: '2026-04-01',
        bankMatched: true,
      );
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: const ['P-26001'],
        description: 'EFT WRONG-REF',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });

    test('a manually matched transaction with a mismatched reference stays '
        'unmatched if its date was never stamped to the bank row (pre-fix behaviour)', () {
      final txn = _tx(
        id: '1',
        receipt: 'WRONG-REF',
        type: 'credit',
        total: 5000,
        date: '2026-03-15', // stale — never updated to the statement's clearing date
        bankMatched: true,
      );
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: const ['P-26001'],
        description: 'EFT WRONG-REF',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.unmatched);
    });

    test('a Payment Reference on a credit transaction plays no part (Money-Out only field)', () {
      // Credit transactions never carry a Payment Reference in practice, but
      // matchCbaCreditRow only ever consults parsedReceipts/date+amount —
      // confirms there's no accidental cross-wiring with the debit path.
      final txn = _tx(id: '1', receipt: 'P-26001', type: 'credit', paymentReference: 'SHOULD-BE-IGNORED');
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'SHOULD-BE-IGNORED',
        amountCents: 9999, // deliberately not matching total, to prove no reference match occurred
      );
      expect(result.status, BankMatchStatus.unmatched);
    });
  });
}
