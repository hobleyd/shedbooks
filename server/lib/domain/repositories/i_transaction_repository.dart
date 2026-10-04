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

import '../entities/transaction.dart';
import '../entities/transaction_line.dart';

/// Contract for transaction persistence.
abstract interface class ITransactionRepository {
  /// Creates a new transaction and returns the persisted entity.
  /// Throws [TransactionValidationException] on FK violations.
  Future<Transaction> create({
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
    String? bankAccountId,
  });

  /// Creates one transaction row per entry in [lines], all sharing the given
  /// contact, date, receipt number, payment reference, bank account and cash
  /// flag, tied together by a new split group id. Every row is written in a
  /// single database transaction — either all lines persist or none do.
  /// Returns the persisted rows in line order.
  /// Throws [TransactionValidationException] on FK violations.
  Future<List<Transaction>> createSplit({
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    bool isCash = false,
    String? bankAccountId,
    required List<TransactionLine> lines,
  });

  /// Soft-deletes the transactions in [replacedIds] and writes [lines] in
  /// their place, in a single database transaction. More than one line is
  /// stored as a split (sharing a new split group id); exactly one line is
  /// stored as an ordinary transaction. [bankMatched] and [abaBatchName]
  /// carry the replaced rows' reconciliation / bank-upload state over to the
  /// new rows. Returns the persisted rows in line order.
  /// Throws [TransactionValidationException] on FK violations.
  Future<List<Transaction>> replaceWithLines({
    required List<String> replacedIds,
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    bool isCash = false,
    bool bankMatched = false,
    String? abaBatchName,
    String? bankAccountId,
    required List<TransactionLine> lines,
  });

  /// Returns the active rows of the split [splitGroupId] within [entityId],
  /// in line order. Empty when the group does not exist.
  Future<List<Transaction>> findBySplitGroup(String splitGroupId,
      {required String entityId});

  /// Soft-deletes every active row of the split [splitGroupId] within [entityId].
  Future<void> deleteSplitGroup(String splitGroupId, {required String entityId});

  /// Returns a transaction by [id] within [entityId], or null if not found / deleted.
  Future<Transaction?> findById(String id, {required String entityId});

  /// Returns all active transactions for [entityId] ordered by [transactionDate] descending.
  Future<List<Transaction>> findAll({required String entityId});

  /// Updates an existing transaction and returns the updated entity.
  /// Throws [TransactionNotFoundException] if [id] does not exist within [entityId].
  /// Throws [TransactionValidationException] on FK violations.
  Future<Transaction> update({
    required String id,
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
    bool bankMatched = false,
    String? bankAccountId,
  });

  /// Soft-deletes the transaction with [id] within [entityId].
  /// Throws [TransactionNotFoundException] if [id] does not exist within [entityId].
  Future<void> delete(String id, {required String entityId});

  /// Returns true if any active transaction references [contactId] within [entityId].
  Future<bool> hasTransactions(String contactId, {required String entityId});

  /// Reassigns all active transactions whose contact matches any of [fromContactIds]
  /// to [toContactId] within [entityId].
  Future<void> reassignContact(
    List<String> fromContactIds,
    String toContactId, {
    required String entityId,
  });

  /// Marks all transactions in [ids] as bank-matched within [entityId], recording
  /// [bankAccountId] as the account they were reconciled against (if known).
  /// When [transactionDate] is given, it replaces each transaction's existing
  /// date with the bank statement row's clearing date — otherwise a manually
  /// matched transaction keeps whatever date it was created with, which can
  /// cause it to fail date-based re-detection on a later import/reconciliation.
  /// Matching any line of a split matches every line of that split, since
  /// together they are one payment on the bank statement.
  /// Silently ignores IDs that do not exist or are already matched.
  Future<void> bankMatch(
    List<String> ids, {
    required String entityId,
    String? bankAccountId,
    DateTime? transactionDate,
  });

  /// Stamps [batchName] on all transactions in [ids] within [entityId].
  /// Stamping any line of a split stamps every line of that split.
  Future<void> stampAbaBatch(
    List<String> ids,
    String batchName, {
    required String entityId,
  });

}
