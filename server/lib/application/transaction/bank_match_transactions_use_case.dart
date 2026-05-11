import '../../domain/repositories/i_transaction_repository.dart';

/// Marks a set of transactions as bank-matched.
class BankMatchTransactionsUseCase {
  final ITransactionRepository _repository;

  const BankMatchTransactionsUseCase(this._repository);

  /// Sets [bank_matched = true] for all [ids] within [entityId].
  Future<void> execute({
    required List<String> ids,
    required String entityId,
  }) async {
    if (ids.isEmpty) return;
    await _repository.bankMatch(ids, entityId: entityId);
  }
}
