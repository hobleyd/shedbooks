import '../entities/closing_bank_balance.dart';

/// Repository contract for [ClosingBankBalance] persistence.
abstract class IClosingBankBalanceRepository {
  /// Inserts or updates the closing balance for the given bank account and date.
  ///
  /// Uses UPSERT on (entity_id, bank_account_id, balance_date) so that
  /// re-running a reconciliation for the same period updates the record.
  Future<ClosingBankBalance> save({
    required String entityId,
    required String bankAccountId,
    required String balanceDate,
    required int balanceCents,
    required String statementPeriod,
  });

  /// Returns all closing balances for [bankAccountId], ordered by date descending.
  Future<List<ClosingBankBalance>> findByBankAccount({
    required String entityId,
    required String bankAccountId,
  });
}
