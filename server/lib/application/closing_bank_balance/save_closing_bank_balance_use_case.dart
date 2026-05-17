import '../../domain/entities/closing_bank_balance.dart';
import '../../domain/repositories/i_closing_bank_balance_repository.dart';

/// Inserts or updates the closing bank balance for a given period.
class SaveClosingBankBalanceUseCase {
  final IClosingBankBalanceRepository _repository;

  const SaveClosingBankBalanceUseCase(this._repository);

  /// Upserts the closing balance and returns the persisted record.
  Future<ClosingBankBalance> execute({
    required String entityId,
    required String bankAccountId,
    required String balanceDate,
    required int balanceCents,
    required String statementPeriod,
  }) =>
      _repository.save(
        entityId: entityId,
        bankAccountId: bankAccountId,
        balanceDate: balanceDate,
        balanceCents: balanceCents,
        statementPeriod: statementPeriod,
      );
}
