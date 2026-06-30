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
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
  });

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
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
    bool bankMatched = false,
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

  /// Marks all transactions in [ids] as bank-matched within [entityId].
  /// Silently ignores IDs that do not exist or are already matched.
  Future<void> bankMatch(List<String> ids, {required String entityId});

  /// Stamps [batchName] on all transactions in [ids] within [entityId].
  Future<void> stampAbaBatch(
    List<String> ids,
    String batchName, {
    required String entityId,
  });

}
