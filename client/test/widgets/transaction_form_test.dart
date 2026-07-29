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

Widget _harness() => MaterialApp(
      home: Scaffold(
        body: TransactionForm(
          contacts: const [
            ContactEntry(
                id: 'c1', name: 'Acme', contactType: ContactType.company, gstRegistered: true),
          ],
          glEntries: const [_gl],
          nextMoneyOutReceipt: 'P-26002',
          initial: _tx,
          compact: true,
          isSaving: false,
          onSave: (_) {},
        ),
      ),
    );

Finder _fieldLabeled(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    );

void main() {
  testWidgets('editing GST after Total was set recalculates Amount ex GST',
      (tester) async {
    await tester.pumpWidget(_harness());
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
    await tester.pumpWidget(_harness());
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
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final gstField = tester.widget<TextFormField>(_fieldLabeled('GST'));
    expect(gstField.enabled, isTrue);
  });
}
