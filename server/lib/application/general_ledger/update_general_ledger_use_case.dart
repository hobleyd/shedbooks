import '../../domain/entities/general_ledger.dart';
import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Updates an existing general ledger account.
class UpdateGeneralLedgerUseCase {
  final IGeneralLedgerRepository _repository;

  const UpdateGeneralLedgerUseCase(this._repository);

  Future<GeneralLedger> execute({
    required String id,
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
  }) async {
    if (label.trim().isEmpty) {
      throw const GeneralLedgerValidationException('Label must not be empty');
    }
    if (description.trim().isEmpty) {
      throw const GeneralLedgerValidationException('Description must not be empty');
    }

    return _repository.update(
      id: id,
      entityId: entityId,
      label: label.trim(),
      description: description.trim(),
      gstApplicable: gstApplicable,
      direction: direction,
    );
  }
}
