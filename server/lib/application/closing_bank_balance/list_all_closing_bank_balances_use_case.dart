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

import '../../domain/entities/closing_bank_balance.dart';
import '../../domain/repositories/i_closing_bank_balance_repository.dart';

/// Returns all closing bank balances for the authenticated entity.
class ListAllClosingBankBalancesUseCase {
  final IClosingBankBalanceRepository _repository;

  const ListAllClosingBankBalancesUseCase(this._repository);

  /// Returns all balances for the entity, ordered by date descending.
  Future<List<ClosingBankBalance>> execute({
    required String entityId,
  }) =>
      _repository.findAllForEntity(entityId: entityId);
}
