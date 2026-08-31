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

import 'general_ledger_entry.dart';
import 'transaction_entry.dart';

class GlLine {
  final GeneralLedgerEntry gl;
  int totalCents = 0;
  final List<TransactionEntry> transactions = [];
  GlLine(this.gl);
}

class PnLData {
  final List<GlLine> incomeLines;
  final List<GlLine> expenseLines;
  final int totalIncome;
  final int totalExpenses;
  final int netProfit;
  final List<TransactionEntry> periodTransactions;

  PnLData({
    required this.incomeLines,
    required this.expenseLines,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netProfit,
    required this.periodTransactions,
  });

  factory PnLData.compute({
    required List<TransactionEntry> allTransactions,
    required Map<String, GeneralLedgerEntry> glMap,
    required bool Function(TransactionEntry) filter,
  }) {
    final periodTxns = allTransactions.where(filter).toList();

    List<GlLine> groupByGl(List<TransactionEntry> txns, bool credits) {
      final Map<String, GlLine> map = {};
      for (final TransactionEntry t in txns.where((TransactionEntry t) => t.isCredit == credits)) {
        final GeneralLedgerEntry? gl = glMap[t.generalLedgerId];
        if (gl == null) continue;
        final GlLine line = map[gl.id] ??= GlLine(gl);
        line.totalCents += t.totalAmount;
        line.transactions.add(t);
      }
      return map.values.toList()
        ..sort((GlLine a, GlLine b) => a.gl.label.compareTo(b.gl.label));
    }

    final incomeLines = groupByGl(periodTxns, true);
    final expenseLines = groupByGl(periodTxns, false);

    final totalIncome = incomeLines.fold(0, (s, l) => s + l.totalCents);
    final totalExpenses = expenseLines.fold(0, (s, l) => s + l.totalCents);

    return PnLData(
      incomeLines: incomeLines,
      expenseLines: expenseLines,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netProfit: totalIncome - totalExpenses,
      periodTransactions: periodTxns,
    );
  }
}
