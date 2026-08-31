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

void main() {
  group('PnLData.compute', () {
    test('expense line on a GST-applicable GL account totals the GST-inclusive amount', () {
      const gl = GeneralLedgerEntry(
        id: 'gl-1',
        label: 'Purchases',
        description: 'Purchases',
        gstApplicable: true,
        direction: GlDirection.moneyOut,
      );
      const txn = TransactionEntry(
        id: 't-1',
        contactId: 'c-1',
        generalLedgerId: 'gl-1',
        receiptNumber: 'P-26141',
        description: 'Childers Bakery',
        transactionType: 'debit',
        amount: 20929,
        gstAmount: 2093,
        totalAmount: 23022,
        transactionDate: '2026-06-01',
      );

      final data = PnLData.compute(
        allTransactions: [txn],
        glMap: {'gl-1': gl},
        filter: (_) => true,
      );

      expect(data.expenseLines, hasLength(1));
      expect(data.expenseLines.single.totalCents, 23022);
      expect(data.totalExpenses, 23022);
    });

    test('income line totals the GST-inclusive amount, matching expense treatment', () {
      const gl = GeneralLedgerEntry(
        id: 'gl-2',
        label: 'Sales',
        description: 'Sales',
        gstApplicable: true,
        direction: GlDirection.moneyIn,
      );
      const txn = TransactionEntry(
        id: 't-2',
        contactId: 'c-2',
        generalLedgerId: 'gl-2',
        receiptNumber: 'R-1',
        description: 'Sale',
        transactionType: 'credit',
        amount: 20929,
        gstAmount: 2093,
        totalAmount: 23022,
        transactionDate: '2026-06-01',
      );

      final data = PnLData.compute(
        allTransactions: [txn],
        glMap: {'gl-2': gl},
        filter: (_) => true,
      );

      expect(data.incomeLines.single.totalCents, 23022);
      expect(data.totalIncome, 23022);
    });
  });
}
