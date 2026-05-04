import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Retrieves a single transaction by ID.
class GetTransactionUseCase {
  final ITransactionRepository _repository;

  const GetTransactionUseCase(this._repository);

  /// Returns the transaction or throws [TransactionNotFoundException].
  Future<Transaction> execute(String id) async {
    final transaction = await _repository.findById(id);
    if (transaction == null) throw TransactionNotFoundException(id);
    return transaction;
  }
}
