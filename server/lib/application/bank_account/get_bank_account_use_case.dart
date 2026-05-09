import '../../domain/entities/bank_account.dart';
import '../../domain/exceptions/bank_account_exception.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Retrieves a single bank account by ID.
class GetBankAccountUseCase {
  final IBankAccountRepository _repository;

  const GetBankAccountUseCase(this._repository);

  Future<BankAccount> execute(String id, {required String entityId}) async {
    final account = await _repository.findById(id, entityId: entityId);
    if (account == null) throw BankAccountNotFoundException(id);
    return account;
  }
}
