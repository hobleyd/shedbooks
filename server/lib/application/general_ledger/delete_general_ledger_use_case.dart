import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Soft-deletes a general ledger account.
class DeleteGeneralLedgerUseCase {
  final IGeneralLedgerRepository _repository;

  const DeleteGeneralLedgerUseCase(this._repository);

  Future<void> execute(String id, {required String entityId}) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw GeneralLedgerNotFoundException(id);
    await _repository.delete(id, entityId: entityId);
  }
}
