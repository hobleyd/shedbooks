import '../../domain/entities/general_ledger.dart';
import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Retrieves a single general ledger account by ID.
class GetGeneralLedgerUseCase {
  final IGeneralLedgerRepository _repository;

  const GetGeneralLedgerUseCase(this._repository);

  /// Returns the account or throws [GeneralLedgerNotFoundException].
  Future<GeneralLedger> execute(String id) async {
    final account = await _repository.findById(id);
    if (account == null) {
      throw GeneralLedgerNotFoundException(id);
    }
    return account;
  }
}
