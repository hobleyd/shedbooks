import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Retrieves a single transaction by ID.
class GetTransactionUseCase {
  final ITransactionRepository _repository;

  const GetTransactionUseCase(this._repository);

  Future<Transaction> execute(String id, {required String entityId}) async {
    final transaction = await _repository.findById(id, entityId: entityId);
    if (transaction == null) throw TransactionNotFoundException(id);
    return transaction;
  }
}
