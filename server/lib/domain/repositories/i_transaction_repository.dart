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
  });

  /// Soft-deletes the transaction with [id] within [entityId].
  /// Throws [TransactionNotFoundException] if [id] does not exist within [entityId].
  Future<void> delete(String id, {required String entityId});
}
