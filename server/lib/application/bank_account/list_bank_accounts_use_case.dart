import '../../domain/entities/bank_account.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Lists all bank accounts for an entity.
class ListBankAccountsUseCase {
  final IBankAccountRepository _repository;

  const ListBankAccountsUseCase(this._repository);

  Future<List<BankAccount>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
