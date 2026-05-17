import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// Creates a new financial transaction.
class CreateTransactionUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const CreateTransactionUseCase(this._repository, this._lockedMonths);

  Future<Transaction> execute({
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

    final monthYear = _monthYear(transactionDate);
    if (await _lockedMonths.isLocked(entityId, monthYear)) {
      throw MonthIsLockedException(monthYear);
    }

    return _repository.create(
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
