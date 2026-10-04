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

import '../models/transaction_entry.dart';

/// One real-world payment: either a single ordinary transaction, or every
/// line of a split transaction (one payment coded to several GL accounts).
///
/// Reports work per line; anything that deals with money actually moving —
/// the bank (ABA) upload and bank reconciliation — must work per payment, or
/// a split would be paid or matched once per line.
class TransactionPayment {
  /// The rows making up the payment, in split line order. Never empty.
  final List<TransactionEntry> lines;

  const TransactionPayment(this.lines);

  /// The first line — carries every field the lines share (contact, date,
  /// receipt number, payment reference, bank account).
  TransactionEntry get first => lines.first;

  /// Total of every line including GST, in cents.
  int get totalAmount =>
      lines.fold(0, (int sum, TransactionEntry t) => sum + t.totalAmount);

  List<String> get ids => [for (final TransactionEntry t in lines) t.id];
}

/// Every row of the split [t] belongs to, in line order, found within [all].
/// Returns just `[t]` when [t] is an ordinary transaction.
List<TransactionEntry> splitLinesOf(
  TransactionEntry t,
  Iterable<TransactionEntry> all,
) {
  final String? groupId = t.splitGroupId;
  if (groupId == null) return [t];
  final List<TransactionEntry> lines =
      all.where((TransactionEntry o) => o.splitGroupId == groupId).toList()
        ..sort((a, b) => (a.splitLineNo ?? 0).compareTo(b.splitLineNo ?? 0));
  return lines.isEmpty ? [t] : lines;
}

/// Collapses [transactions] into payments, keeping first-seen order: rows
/// sharing a split group become one [TransactionPayment], every other row is
/// a payment on its own.
List<TransactionPayment> groupIntoPayments(
  Iterable<TransactionEntry> transactions,
) {
  final List<TransactionPayment> payments = [];
  final Map<String, List<TransactionEntry>> groups = {};
  for (final TransactionEntry t in transactions) {
    final String? groupId = t.splitGroupId;
    if (groupId == null) {
      payments.add(TransactionPayment([t]));
      continue;
    }
    final List<TransactionEntry>? existing = groups[groupId];
    if (existing != null) {
      existing.add(t);
    } else {
      final List<TransactionEntry> lines = [t];
      groups[groupId] = lines;
      payments.add(TransactionPayment(lines));
    }
  }
  for (final List<TransactionEntry> lines in groups.values) {
    lines.sort((a, b) => (a.splitLineNo ?? 0).compareTo(b.splitLineNo ?? 0));
  }
  return payments;
}
