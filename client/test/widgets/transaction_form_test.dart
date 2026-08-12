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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/bank_account_summary.dart';
import 'package:shedbooks_client/models/contact_entry.dart';
import 'package:shedbooks_client/models/general_ledger_entry.dart';
import 'package:shedbooks_client/models/transaction_entry.dart';
import 'package:shedbooks_client/widgets/transaction_form.dart';

const _gl = GeneralLedgerEntry(
  id: 'gl1',
  label: 'Stationery',
  description: 'Stationery',
  gstApplicable: true,
  direction: GlDirection.moneyOut,
);

const _glOther = GeneralLedgerEntry(
  id: 'gl3',
  label: 'Postage',
  description: 'Postage',
  gstApplicable: true,
  direction: GlDirection.moneyOut,
);

const _glNoGst = GeneralLedgerEntry(
  id: 'gl2',
  label: 'Wages',
  description: 'Wages',
  gstApplicable: false,
  direction: GlDirection.moneyOut,
);

final _tx = TransactionEntry(
  id: 't1',
  contactId: 'c1',
  generalLedgerId: 'gl1',
  receiptNumber: 'P-26001',
  description: '',
  transactionType: 'debit',
  amount: 10000,
  gstAmount: 1000,
  totalAmount: 11000,
  transactionDate: '2026-04-01',
);

const _glIn = GeneralLedgerEntry(
  id: 'gl4',
  label: 'Membership Fees',
  description: 'Membership Fees',
  gstApplicable: true,
  direction: GlDirection.moneyIn,
);

const _contacts = [
  ContactEntry(id: 'c1', name: 'Acme', contactType: ContactType.company, gstRegistered: true),
];

const _bankCash = BankAccountSummary(
  id: 'cash1',
  accountName: 'Cash',
  bankName: 'Cash',
  bsb: '000000',
  accountNumber: '000000000',
  accountType: 'cash',
);
const _bankA = BankAccountSummary(
  id: 'bank1',
  accountName: 'Everyday Account',
  bankName: 'CBA',
  bsb: '062000',
  accountNumber: '12345678',
  accountType: 'transaction',
);
const _bankB = BankAccountSummary(
  id: 'bank2',
  accountName: 'Savings Account',
  bankName: 'CBA',
  bsb: '062000',
  accountNumber: '87654321',
  accountType: 'savings',
);
// Two non-cash accounts — deliberately ambiguous, so the form must not
// silently default to either one; the user has to pick.
const _multiBankAccounts = [_bankCash, _bankA, _bankB];

Widget _editHarness() => MaterialApp(
      home: Scaffold(
        body: TransactionForm(
          contacts: _contacts,
          glEntries: const [_gl, _glOther, _glNoGst],
          nextMoneyOutReceipt: 'P-26002',
          initial: _tx,
          compact: true,
          isSaving: false,
          onSave: (_) {},
        ),
      ),
    );

/// Mirrors the real "Add transaction" row: no [initial], so the form starts
/// with no GL account selected — matching the reported bug scenario.
Widget _addHarness() => MaterialApp(
      home: Scaffold(
        body: TransactionForm(
          contacts: _contacts,
          glEntries: const [_gl, _glNoGst],
          nextMoneyOutReceipt: 'P-26002',
          initialDirection: GlDirection.moneyOut,
          compact: true,
          isSaving: false,
          onSave: (_) {},
        ),
      ),
    );

/// Compact "Add transaction" harness with multiple bank accounts, so the
/// account dropdown has real choices instead of just Cash.
Widget _multiAccountHarness(
  GlDirection direction, {
  void Function(TransactionFormData)? onSave,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TransactionForm(
          contacts: _contacts,
          glEntries: const [_gl, _glNoGst, _glIn],
          bankAccounts: _multiBankAccounts,
          nextMoneyOutReceipt: 'P-26002',
          initialDirection: direction,
          compact: true,
          isSaving: false,
          onSave: onSave ?? (_) {},
        ),
      ),
    );

Finder _fieldLabeled(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    );

Future<void> _selectGlAccount(WidgetTester tester, String description) async {
  await tester.tap(find.byType(DropdownButton<GeneralLedgerEntry>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(description).last);
  await tester.pumpAndSettle();
}

Future<void> _selectAccount(WidgetTester tester, String accountName) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(accountName).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editing GST after Total was set recalculates Amount ex GST',
      (tester) async {
    await tester.pumpWidget(_editHarness());
    await tester.pumpAndSettle();

    // Sanity: initial state loaded from the transaction (Total anchor by default).
    expect(find.widgetWithText(TextFormField, '110.00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '100.00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10.00'), findsOneWidget);

    // Re-enter Total (to a new value) to set the anchor to "total".
    await tester.enterText(_fieldLabeled('Total'), '121.00');
    await tester.pump();

    // Now edit GST directly — Amount ex GST should move, Total should stay put.
    await tester.enterText(_fieldLabeled('GST'), '5.00');
    await tester.pump();

    expect(find.widgetWithText(TextFormField, '121.00'), findsOneWidget); // Total unchanged
    expect(find.widgetWithText(TextFormField, '116.00'), findsOneWidget); // Amount = 121 - 5
  });

  testWidgets('editing GST after Amount ex GST was set recalculates Total',
      (tester) async {
    await tester.pumpWidget(_editHarness());
    await tester.pumpAndSettle();

    // Edit Amount ex GST directly (to a new value) to set the anchor to "amount".
    await tester.enterText(_fieldLabeled('Amt ex GST'), '120.00');
    await tester.pump();

    // Now edit GST directly — Total should move, Amount ex GST should stay put.
    await tester.enterText(_fieldLabeled('GST'), '5.00');
    await tester.pump();

    expect(find.widgetWithText(TextFormField, '120.00'), findsOneWidget); // Amount unchanged
    expect(find.widgetWithText(TextFormField, '125.00'), findsOneWidget); // Total = 120 + 5
  });

  testWidgets('GST field is editable when the GL account is GST-applicable',
      (tester) async {
    await tester.pumpWidget(_editHarness());
    await tester.pumpAndSettle();

    final gstField = tester.widget<TextFormField>(_fieldLabeled('GST'));
    expect(gstField.enabled, isTrue);
  });

  group('GST-exempt GL account', () {
    testWidgets('GST field is disabled and pinned to 0.00', (tester) async {
      await tester.pumpWidget(_editHarness());
      await tester.pumpAndSettle();

      await _selectGlAccount(tester, 'Wages');

      final gstField = tester.widget<TextFormField>(_fieldLabeled('GST'));
      expect(gstField.enabled, isFalse);
      expect(find.widgetWithText(TextFormField, '0.00'), findsOneWidget);
    });

    testWidgets('switching from a GST-applicable account folds Total into Amount ex GST',
        (tester) async {
      await tester.pumpWidget(_editHarness());
      await tester.pumpAndSettle();

      // Starts as the GST-applicable initial transaction: Total 110.00, Amount 100.00, GST 10.00.
      await _selectGlAccount(tester, 'Wages');

      expect(find.widgetWithText(TextFormField, '110.00'), findsNWidgets(2)); // Total & Amount
      expect(find.widgetWithText(TextFormField, '0.00'), findsOneWidget); // GST collapsed
    });
  });

  group('Add transaction (no GL account selected yet)', () {
    testWidgets('GST field starts disabled until a GL account is chosen', (tester) async {
      await tester.pumpWidget(_addHarness());
      await tester.pumpAndSettle();

      final gstField = tester.widget<TextFormField>(_fieldLabeled('GST'));
      expect(gstField.enabled, isFalse);
    });

    testWidgets(
        'selecting a GST-applicable account enables GST, and entering Total then editing '
        'GST recalculates Amount ex GST', (tester) async {
      await tester.pumpWidget(_addHarness());
      await tester.pumpAndSettle();

      await _selectGlAccount(tester, 'Stationery');
      expect(tester.widget<TextFormField>(_fieldLabeled('GST')).enabled, isTrue);

      await tester.enterText(_fieldLabeled('Total'), '110.00');
      await tester.pump();
      expect(find.widgetWithText(TextFormField, '100.00'), findsOneWidget); // Amount
      expect(find.widgetWithText(TextFormField, '10.00'), findsOneWidget); // GST

      await tester.enterText(_fieldLabeled('GST'), '5.00');
      await tester.pump();

      expect(find.widgetWithText(TextFormField, '110.00'), findsOneWidget); // Total unchanged
      expect(find.widgetWithText(TextFormField, '105.00'), findsOneWidget); // Amount = 110 - 5
    });

    testWidgets(
        'entering Amount ex GST then editing GST recalculates Total, leaving Amount unchanged',
        (tester) async {
      await tester.pumpWidget(_addHarness());
      await tester.pumpAndSettle();

      await _selectGlAccount(tester, 'Stationery');
      await tester.enterText(_fieldLabeled('Amt ex GST'), '100.00');
      await tester.pump();
      expect(find.widgetWithText(TextFormField, '10.00'), findsOneWidget); // GST
      expect(find.widgetWithText(TextFormField, '110.00'), findsOneWidget); // Total

      await tester.enterText(_fieldLabeled('GST'), '20.00');
      await tester.pump();

      expect(find.widgetWithText(TextFormField, '100.00'), findsOneWidget); // Amount unchanged
      expect(find.widgetWithText(TextFormField, '120.00'), findsOneWidget); // Total = 100 + 20
    });
  });

  group('Account dropdown (replaces the Cash checkbox)', () {
    testWidgets('Money-In: selecting Cash shows the receipt number field',
        (tester) async {
      await tester.pumpWidget(_multiAccountHarness(GlDirection.moneyIn));
      await tester.pumpAndSettle();

      expect(_fieldLabeled('Receipt No.'), findsNothing);

      await _selectAccount(tester, 'Cash');

      expect(_fieldLabeled('Receipt No.'), findsOneWidget);
    });

    testWidgets(
        'Money-In: selecting a bank account hides the receipt field and '
        'submits receiptNumber "Bank Transfer"', (tester) async {
      TransactionFormData? captured;
      await tester.pumpWidget(
        _multiAccountHarness(GlDirection.moneyIn, onSave: (d) => captured = d),
      );
      await tester.pumpAndSettle();

      await _selectAccount(tester, 'Everyday Account');
      expect(_fieldLabeled('Receipt No.'), findsNothing);

      await _selectGlAccount(tester, 'Membership Fees');
      await tester.enterText(_fieldLabeled('Contact'), 'Acme');
      await tester.enterText(_fieldLabeled('Total'), '110.00');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.receiptNumber, 'Bank Transfer');
      expect(captured!.isCash, isFalse);
      expect(captured!.bankAccountId, 'bank1');
    });

    testWidgets(
        'Money-Out: receipt number text survives switching between accounts',
        (tester) async {
      await tester.pumpWidget(_multiAccountHarness(GlDirection.moneyOut));
      await tester.pumpAndSettle();

      await _selectAccount(tester, 'Cash');
      expect(_fieldLabeled('Receipt No.'), findsOneWidget);
      await tester.enterText(_fieldLabeled('Receipt No.'), 'CASH-999');
      await tester.pump();

      // Switching to a bank account swaps to the auto-generated receipt
      // field — it must still hold its own untouched value.
      await _selectAccount(tester, 'Everyday Account');
      expect(find.widgetWithText(TextFormField, 'P-26002'), findsOneWidget);

      // Switching back to Cash must NOT have cleared what was typed earlier.
      await _selectAccount(tester, 'Cash');
      expect(find.widgetWithText(TextFormField, 'CASH-999'), findsOneWidget);
    });

    testWidgets(
        'editing a transaction whose bankAccountId is not in the current '
        'account list does not crash', (tester) async {
      final txStaleAccount = TransactionEntry(
        id: 't9',
        contactId: 'c1',
        generalLedgerId: 'gl1',
        receiptNumber: 'REC-777',
        description: '',
        transactionType: 'debit',
        amount: 5000,
        gstAmount: 500,
        totalAmount: 5500,
        transactionDate: '2026-04-01',
        bankAccountId: 'deleted-account-id',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionForm(
            contacts: _contacts,
            glEntries: const [_gl, _glOther, _glNoGst],
            bankAccounts: _multiBankAccounts,
            nextMoneyOutReceipt: 'P-26002',
            initial: txStaleAccount,
            compact: true,
            isSaving: false,
            onSave: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
