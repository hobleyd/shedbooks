import '../../domain/repositories/i_bank_account_repository.dart';

/// Persists a user-defined ordering for bank accounts.
class ReorderBankAccountsUseCase {
  final IBankAccountRepository _repository;

  const ReorderBankAccountsUseCase(this._repository);

  /// Sets sort_order of each account to its position in [ids].
  /// IDs not belonging to [entityId] are silently ignored by the repository.
  Future<void> execute(
      {required String entityId, required List<String> ids}) async {
    await _repository.reorder(entityId: entityId, ids: ids);
  }
}
