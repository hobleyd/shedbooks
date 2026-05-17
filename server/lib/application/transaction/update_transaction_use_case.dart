import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// Updates an existing transaction.
class UpdateTransactionUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const UpdateTransactionUseCase(this._repository, this._lockedMonths);

  Future<Transaction> execute({
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
  }) async {
    TransactionValidator.validate(
      amount: amount,
      gstAmount: gstAmount,
      receiptNumber: receiptNumber,
    );

    // Check both the existing transaction's month and the new target month.
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw TransactionNotFoundException(id);

    final existingMonth = _monthYear(existing.transactionDate);
    if (await _lockedMonths.isLocked(entityId, existingMonth)) {
      throw MonthIsLockedException(existingMonth);
    }

    final newMonth = _monthYear(transactionDate);
    if (newMonth != existingMonth &&
        await _lockedMonths.isLocked(entityId, newMonth)) {
      throw MonthIsLockedException(newMonth);
    }

    return _repository.update(
      id: id,
      entityId: entityId,
      contactId: contactId,
      generalLedgerId: generalLedgerId,
      amount: amount,
      gstAmount: gstAmount,
      transactionType: transactionType,
      receiptNumber: receiptNumber.trim(),
      description: description.trim(),
      transactionDate: transactionDate,
    );
  }

  static String _monthYear(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
