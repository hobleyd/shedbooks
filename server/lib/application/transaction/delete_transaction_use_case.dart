import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Soft-deletes a transaction.
class DeleteTransactionUseCase {
  final ITransactionRepository _repository;

  const DeleteTransactionUseCase(this._repository);

  Future<void> execute(String id, {required String entityId}) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw TransactionNotFoundException(id);
    await _repository.delete(id, entityId: entityId);
  }
}
