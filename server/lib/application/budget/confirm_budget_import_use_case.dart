// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
