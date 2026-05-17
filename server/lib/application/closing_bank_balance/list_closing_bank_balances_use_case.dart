import '../../domain/entities/closing_bank_balance.dart';
import '../../domain/repositories/i_closing_bank_balance_repository.dart';

/// Returns all closing bank balances for a given bank account.
class ListClosingBankBalancesUseCase {
  final IClosingBankBalanceRepository _repository;

  const ListClosingBankBalancesUseCase(this._repository);

  /// Returns balances for [bankAccountId] ordered by date descending.
  Future<List<ClosingBankBalance>> execute({
    required String entityId,
    required String bankAccountId,
  }) =>
      _repository.findByBankAccount(
        entityId: entityId,
        bankAccountId: bankAccountId,
      );
}
