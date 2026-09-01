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

/// Whether [transaction] is what a bank statement row's description refers
/// to — either its Receipt No. was recognised among [parsedReceipts]
/// (extracted from the statement text using the entity's configured
/// receipt-number format), or — Money-Out only — its Payment Reference
/// appears literally in [description]. A bank upload (ABA file) uses the
/// Payment Reference as the lodgement reference in place of the Receipt No.
/// when one is set, so that's what shows up on the statement instead.
bool referenceMatches({
  required List<String> parsedReceipts,
  required String description,
  required TransactionEntry transaction,
}) {
  if (parsedReceipts.contains(transaction.receiptNumber)) return true;
  final ref = transaction.paymentReference?.trim();
  if (ref == null || ref.isEmpty) return false;
  return description.toUpperCase().contains(ref.toUpperCase());
}

final _abaBatchNamePattern = RegExp(r'WMS\d{9}');

/// Extracts a WMS ABA batch name (e.g. `WMS260620001`) from a bank statement
/// description, or `null` if none is present.
String? extractAbaBatchName(String description) =>
    _abaBatchNamePattern.firstMatch(description)?[0];
