import '../entities/transaction.dart';

/// Contract for transaction persistence.
abstract interface class ITransactionRepository {
  /// Creates a new transaction and returns the persisted entity.
  /// Throws [TransactionValidationException] on FK violations.
  Future<Transaction> create({
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    required DateTime transactionDate,
  });

  /// Returns a transaction by [id], or null if not found / deleted.
  Future<Transaction?> findById(String id);

  /// Returns all active transactions ordered by [transactionDate] descending.
  Future<List<Transaction>> findAll();

  /// Updates an existing transaction and returns the updated entity.
  /// Throws [TransactionNotFoundException] if [id] does not exist.
  /// Throws [TransactionValidationException] on FK violations.
  Future<Transaction> update({
    required String id,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    required DateTime transactionDate,
  });

  /// Soft-deletes the transaction with [id].
  /// Throws [TransactionNotFoundException] if [id] does not exist.
  Future<void> delete(String id);
}
