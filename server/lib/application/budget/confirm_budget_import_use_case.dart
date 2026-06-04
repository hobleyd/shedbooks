import '../../domain/entities/budget_gl_mapping.dart';
import '../../domain/entities/budget_line.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// A confirmed import row: one external code mapped to a GL account with monthly amounts.
class ConfirmedImportRow {
  final String externalCode;
  final String externalName;
  final String generalLedgerId;

  /// 12-element list in cents; index 0 = January.
  final List<int> months;

  const ConfirmedImportRow({
    required this.externalCode,
    required this.externalName,
    required this.generalLedgerId,
    required this.months,
  });
}

/// Saves confirmed import rows as budget lines and optionally persists GL mappings.
class ConfirmBudgetImportUseCase {
  final IBudgetRepository _repository;

  const ConfirmBudgetImportUseCase(this._repository);

  Future<void> execute({
    required int year,
    required List<ConfirmedImportRow> rows,
    required bool saveMappings,
    required String entityId,
  }) async {
    // Convert rows to BudgetLine entities, aggregating by (glId, month) so that
    // multiple CSV rows mapped to the same GL account are summed rather than duplicated.
    final lineMap = <(String, int), int>{};
    for (final row in rows) {
      for (int m = 0; m < 12; m++) {
        if (row.months[m] != 0) {
          final key = (row.generalLedgerId, m + 1);
          lineMap[key] = (lineMap[key] ?? 0) + row.months[m];
        }
      }
    }
    final lines = lineMap.entries
        .map((e) => BudgetLine(
              generalLedgerId: e.key.$1,
              month: e.key.$2,
              amountCents: e.value,
            ))
        .toList();

    await _repository.saveLines(year, lines, entityId: entityId);

    if (saveMappings) {
      final mappings = rows
          .map((r) => BudgetGlMapping(
                entityId: entityId,
                externalCode: r.externalCode,
                externalName: r.externalName,
                generalLedgerId: r.generalLedgerId,
              ))
          .toList();
      await _repository.saveMappings(mappings, entityId: entityId);
    }
  }
}
