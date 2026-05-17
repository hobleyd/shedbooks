import '../../domain/exceptions/locked_month_exception.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_locked_month_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Soft-deletes a transaction.
class DeleteTransactionUseCase {
  final ITransactionRepository _repository;
  final ILockedMonthRepository _lockedMonths;

  const DeleteTransactionUseCase(this._repository, this._lockedMonths);

  Future<void> execute(String id, {required String entityId}) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw TransactionNotFoundException(id);

    final monthYear = _monthYear(existing.transactionDate);
    if (await _lockedMonths.isLocked(entityId, monthYear)) {
      throw MonthIsLockedException(monthYear);
    }

    await _repository.delete(id, entityId: entityId);
  }

  static String _monthYear(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
