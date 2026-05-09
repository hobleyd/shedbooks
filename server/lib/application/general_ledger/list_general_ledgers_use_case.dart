import '../../domain/entities/general_ledger.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Returns all active general ledger accounts for an entity.
class ListGeneralLedgersUseCase {
  final IGeneralLedgerRepository _repository;

  const ListGeneralLedgersUseCase(this._repository);

  Future<List<GeneralLedger>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
