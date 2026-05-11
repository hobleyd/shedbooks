import '../../domain/entities/bank_import.dart';
import '../../domain/repositories/i_bank_import_repository.dart';

/// Records bank statement rows that were actioned during an import session.
class SaveBankImportsUseCase {
  final IBankImportRepository _repository;

  const SaveBankImportsUseCase(this._repository);

  /// Saves [rows] for [entityId]. Duplicate rows (same key tuple) are ignored.
  Future<void> execute({
    required String entityId,
    required List<({String processDate, String description, int amountCents, bool isDebit})> rows,
  }) async {
    if (rows.isEmpty) return;
    final entities = rows
        .map((r) => BankImport(
              id: '',
              entityId: entityId,
              processDate: r.processDate,
              description: r.description,
              amountCents: r.amountCents,
              isDebit: r.isDebit,
              importedAt: DateTime.now(),
            ))
        .toList();
    await _repository.saveAll(entities);
  }
}
