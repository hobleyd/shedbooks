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

/// Deletes the budget for a calendar year, including all its lines.
class DeleteBudgetUseCase {
  final IBudgetRepository _repository;

  const DeleteBudgetUseCase(this._repository);

  Future<void> execute(int year, {required String entityId}) =>
      _repository.delete(year, entityId: entityId);
}
