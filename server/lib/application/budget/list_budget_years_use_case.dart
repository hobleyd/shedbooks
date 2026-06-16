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

import '../../domain/repositories/i_budget_repository.dart';

/// Returns all calendar years for which an entity has a saved budget.
class ListBudgetYearsUseCase {
  final IBudgetRepository _repository;

  const ListBudgetYearsUseCase(this._repository);

  Future<List<int>> execute({required String entityId}) =>
      _repository.listYears(entityId: entityId);
}
