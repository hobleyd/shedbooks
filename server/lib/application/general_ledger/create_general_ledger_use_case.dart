import '../../domain/entities/general_ledger.dart';
import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Creates a new general ledger account.
class CreateGeneralLedgerUseCase {
  final IGeneralLedgerRepository _repository;

  const CreateGeneralLedgerUseCase(this._repository);

  Future<GeneralLedger> execute({
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

    return _repository.create(
      entityId: entityId,
      label: label.trim(),
      description: description.trim(),
      gstApplicable: gstApplicable,
      direction: direction,
    );
  }
}
