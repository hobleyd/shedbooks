import '../../domain/entities/general_ledger.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Returns all active general ledger accounts.
class ListGeneralLedgersUseCase {
  final IGeneralLedgerRepository _repository;

  const ListGeneralLedgersUseCase(this._repository);

  Future<List<GeneralLedger>> execute() => _repository.findAll();
}
