import '../../domain/exceptions/bank_account_exception.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Soft-deletes a bank account.
class DeleteBankAccountUseCase {
  final IBankAccountRepository _repository;

  const DeleteBankAccountUseCase(this._repository);

  /// Throws [BankAccountNotFoundException] when the account does not exist.
  Future<void> execute(String id, {required String entityId}) async {
    final account = await _repository.findById(id, entityId: entityId);
    if (account == null) throw BankAccountNotFoundException(id);
    await _repository.delete(id, entityId: entityId);
  }
}
