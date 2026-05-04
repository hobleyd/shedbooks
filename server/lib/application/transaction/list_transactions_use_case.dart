import '../../domain/entities/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Returns all active transactions ordered by transaction date descending.
class ListTransactionsUseCase {
  final ITransactionRepository _repository;

  const ListTransactionsUseCase(this._repository);

  Future<List<Transaction>> execute() => _repository.findAll();
}
