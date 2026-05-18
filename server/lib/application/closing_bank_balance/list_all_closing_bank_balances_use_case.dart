import '../../domain/entities/closing_bank_balance.dart';
import '../../domain/repositories/i_closing_bank_balance_repository.dart';

/// Returns all closing bank balances for the authenticated entity.
class ListAllClosingBankBalancesUseCase {
  final IClosingBankBalanceRepository _repository;

  const ListAllClosingBankBalancesUseCase(this._repository);

  /// Returns all balances for the entity, ordered by date descending.
  Future<List<ClosingBankBalance>> execute({
    required String entityId,
  }) =>
      _repository.findAllForEntity(entityId: entityId);
}
