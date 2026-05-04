import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Soft-deletes a transaction.
class DeleteTransactionUseCase {
  final ITransactionRepository _repository;

  const DeleteTransactionUseCase(this._repository);

  /// Throws [TransactionNotFoundException] when [id] does not exist.
  Future<void> execute(String id) async {
    final existing = await _repository.findById(id);
    if (existing == null) throw TransactionNotFoundException(id);
    await _repository.delete(id);
  }
}
