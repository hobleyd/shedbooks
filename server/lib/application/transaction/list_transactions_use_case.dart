import '../../domain/entities/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Returns all active transactions for an entity ordered by transaction date descending.
class ListTransactionsUseCase {
  final ITransactionRepository _repository;

  const ListTransactionsUseCase(this._repository);

  Future<List<Transaction>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
