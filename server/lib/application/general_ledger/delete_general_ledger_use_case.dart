import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Soft-deletes a general ledger account.
class DeleteGeneralLedgerUseCase {
  final IGeneralLedgerRepository _repository;

  const DeleteGeneralLedgerUseCase(this._repository);

  /// Throws [GeneralLedgerNotFoundException] when [id] does not exist.
  Future<void> execute(String id) async {
    final existing = await _repository.findById(id);
    if (existing == null) {
      throw GeneralLedgerNotFoundException(id);
    }
    await _repository.delete(id);
  }
}
