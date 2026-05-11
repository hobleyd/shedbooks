import '../../domain/entities/bank_import.dart';
import '../../domain/repositories/i_bank_import_repository.dart';

/// Returns all previously-imported bank rows for an entity.
class GetBankImportsUseCase {
  final IBankImportRepository _repository;

  const GetBankImportsUseCase(this._repository);

  /// Returns all [BankImport] records for [entityId].
  Future<List<BankImport>> execute(String entityId) =>
      _repository.findAll(entityId);
}
