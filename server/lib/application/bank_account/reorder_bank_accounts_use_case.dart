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

import '../../domain/repositories/i_bank_account_repository.dart';

/// Persists a user-defined ordering for bank accounts.
class ReorderBankAccountsUseCase {
  final IBankAccountRepository _repository;

  const ReorderBankAccountsUseCase(this._repository);

  /// Sets sort_order of each account to its position in [ids].
  /// IDs not belonging to [entityId] are silently ignored by the repository.
  Future<void> execute(
      {required String entityId, required List<String> ids}) async {
    await _repository.reorder(entityId: entityId, ids: ids);
  }
}
