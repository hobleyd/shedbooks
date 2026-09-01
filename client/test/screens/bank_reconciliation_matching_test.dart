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
import 'package:shedbooks_client/models/invoice_entry.dart';
import 'package:shedbooks_client/models/transaction_entry.dart';
import 'package:shedbooks_client/screens/bank_reconciliation_screen.dart';
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

InvoiceEntry _invoice({required String id, required String number, int cents = 5000}) =>
    InvoiceEntry(
      id: id,
      invoiceNumber: number,
      invoiceDate: '2026-04-01',
      contactId: 'c1',
      totalAmountCents: cents,
      totalGstCents: 0,
    );

RecRowMatchResult _debit({
  required List<TransactionEntry> allTransactions,
  Set<String> reservedIds = const {},
  String? selectedBankAccountId,
  List<String> parsedReceipts = const [],
  String description = '',
  int amountCents = 5000,
  String processDate = '2026-04-01',
  Map<String, String> contactNames = const {},
  bool alreadyImportedByKey = false,
}) =>
    matchRecDebitRow(
      allTransactions: allTransactions,
      reservedIds: reservedIds,
      selectedBankAccountId: selectedBankAccountId,
      parsedReceipts: parsedReceipts,
      description: description,
      amountCents: amountCents,
      processDate: processDate,
      contactNames: contactNames,
      alreadyImportedByKey: alreadyImportedByKey,
    );

RecRowMatchResult _credit({
  required List<TransactionEntry> allTransactions,
  Set<String> reservedIds = const {},
  String? selectedBankAccountId,
  List<String> parsedReceipts = const [],
  String description = '',
  int amountCents = 5000,
  String processDate = '2026-04-01',
  Map<String, String> contactNames = const {},
  List<InvoiceEntry> unpaidInvoices = const [],
  bool alreadyImportedByKey = false,
}) =>
    matchRecCreditRow(
      allTransactions: allTransactions,
      reservedIds: reservedIds,
      selectedBankAccountId: selectedBankAccountId,
      parsedReceipts: parsedReceipts,
      description: description,
      amountCents: amountCents,
      processDate: processDate,
      contactNames: contactNames,
      unpaidInvoices: unpaidInvoices,
      alreadyImportedByKey: alreadyImportedByKey,
    );

void main() {
  group('matchRecDebitRow — receipt number matching', () {
    test('matches by receipt number recognised in the statement text', () {
      final txn = _tx(id: '1', receipt: 'P-26062');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
      expect(result.invoiceMatch, isNull);
    });

    test('alreadyImported when the recognised receipt is already bank-matched (any() semantics)', () {
      // Reconciliation's "already matched by receipt" check is a plain any(),
      // unlike the CSV import screen's stricter sum-equals-target check.
      final txn = _tx(id: '1', receipt: 'P-26062', total: 4000, bankMatched: true);
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: ['P-26062'],
        description: 'EFT P26062',
        amountCents: 5000, // does not equal the matched txn's own total
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });
  });

  group('matchRecDebitRow — Payment Reference matching', () {
    test('matches via Payment Reference when no receipt-number format matches the text', () {
      final txn = _tx(id: '1', receipt: 'P-26062', paymentReference: 'INV-9876-REF');
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'EFT INV-9876-REF ACME PTY LTD',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
    });

    test('a recognised Payment Reference does not fall through to the date+amount fuzzy fallback', () {
      final referenced = _tx(
        id: '1',
        receipt: 'P-26062',
        paymentReference: 'INV-9876-REF',
        bankAccountId: 'acct-A',
        total: 5000,
      );
      final decoy = _tx(id: '2', receipt: 'P-99999', total: 5000);
      final result = _debit(
        allTransactions: [referenced, decoy],
        selectedBankAccountId: 'acct-B',
        parsedReceipts: const [],
        description: 'EFT INV-9876-REF ACME PTY LTD',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.unmatched);
      expect(result.matched, isEmpty);
    });
  });

  group('matchRecDebitRow — ABA batch name matching', () {
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

    test('alreadyImported when the batch total is already fully bank-matched', () {
      final txn = _tx(id: '1', total: 5000, abaBatchName: 'WMS260830001', bankMatched: true);
      final result = _debit(
        allTransactions: [txn],
        parsedReceipts: const [],
        description: 'DIRECT DEBIT WMS260830001',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });
  });

  group('matchRecDebitRow — date + amount fallback', () {
    test('a single unmatched candidate on date+amount auto-matches', () {
      final txn = _tx(id: '1', total: 5000, date: '2026-04-01');
      final result = _debit(
        allTransactions: [txn],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.autoMatched);
    });

    test('multiple candidates are disambiguated by contact name', () {
      final a = _tx(id: '1', total: 5000, contactId: 'c1');
      final b = _tx(id: '2', total: 5000, contactId: 'c2');
      final result = _debit(
        allTransactions: [a, b],
        description: 'PAYMENT TO ACME PTY LTD',
        amountCents: 5000,
        contactNames: {'c1': 'Acme Pty Ltd', 'c2': 'Other Co'},
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([a]));
    });

    test('unresolvable multiple candidates need manual selection', () {
      final a = _tx(id: '1', total: 5000);
      final b = _tx(id: '2', total: 5000);
      final result = _debit(
        allTransactions: [a, b],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
      );
      expect(result.status, BankMatchStatus.needsSelection);
    });

    test('alreadyImportedByKey (previously CSV-imported row) is honoured when nothing else matches', () {
      final result = _debit(
        allTransactions: const [],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
        alreadyImportedByKey: true,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });

    test('unmatched when nothing matches and it was not previously imported', () {
      final result = _debit(
        allTransactions: const [],
        description: 'SOME OTHER TEXT',
        amountCents: 5000,
        alreadyImportedByKey: false,
      );
      expect(result.status, BankMatchStatus.unmatched);
    });
  });

  group('matchRecCreditRow', () {
    test('matches by receipt number', () {
      final txn = _tx(id: '1', receipt: 'P-26001', type: 'credit');
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: ['P-26001'],
        description: 'EFT P26001',
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
      expect(result.invoiceMatch, isNull);
    });

    test('alreadyImported by receipt uses any() semantics regardless of amount', () {
      final txn = _tx(id: '1', receipt: 'P-26001', type: 'credit', total: 1234, bankMatched: true);
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: ['P-26001'],
        description: 'EFT P26001',
        amountCents: 9999,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
    });

    test('matches an unpaid invoice by invoice number when no ledger transaction matches', () {
      final invoice = _invoice(id: 'inv-1', number: 'INV-0042');
      final result = _credit(
        allTransactions: const [],
        parsedReceipts: ['INV-0042'],
        description: 'DEPOSIT INV-0042',
        unpaidInvoices: [invoice],
      );
      expect(result.status, BankMatchStatus.invoiceMatched);
      expect(result.invoiceMatch, equals(invoice));
      expect(result.matched, isEmpty);
    });

    test('a ledger transaction match takes priority over an invoice number match', () {
      final txn = _tx(id: '1', receipt: 'INV-0042', type: 'credit');
      final invoice = _invoice(id: 'inv-1', number: 'INV-0042');
      final result = _credit(
        allTransactions: [txn],
        parsedReceipts: ['INV-0042'],
        description: 'DEPOSIT INV-0042',
        unpaidInvoices: [invoice],
      );
      expect(result.status, BankMatchStatus.autoMatched);
      expect(result.matched, equals([txn]));
      expect(result.invoiceMatch, isNull);
    });

    test('falls back to date + amount when nothing is recognised', () {
      final txn = _tx(id: '1', type: 'credit', total: 5000, date: '2026-04-01');
      final result = _credit(
        allTransactions: [txn],
        description: 'DEPOSIT',
        amountCents: 5000,
        processDate: '2026-04-01',
      );
      expect(result.status, BankMatchStatus.autoMatched);
    });

    test('alreadyImportedByKey is honoured in the credit fallback too', () {
      final result = _credit(
        allTransactions: const [],
        description: 'DEPOSIT',
        amountCents: 5000,
        alreadyImportedByKey: true,
      );
      expect(result.status, BankMatchStatus.alreadyImported);
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
  });
}
