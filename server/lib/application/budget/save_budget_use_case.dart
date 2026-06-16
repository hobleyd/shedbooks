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

import '../../domain/entities/budget_line.dart';
import '../../domain/exceptions/budget_exception.dart';
import '../../domain/repositories/i_budget_repository.dart';

/// Replaces all budget lines for a calendar year (upsert semantics).
class SaveBudgetUseCase {
  final IBudgetRepository _repository;

  const SaveBudgetUseCase(this._repository);

  Future<void> execute(
    int year,
    List<BudgetLine> lines, {
    required String entityId,
  }) async {
    if (year < 1900 || year > 2200) {
      throw const BudgetValidationException('Year must be between 1900 and 2200');
    }
    await _repository.saveLines(year, lines, entityId: entityId);
  }
}
