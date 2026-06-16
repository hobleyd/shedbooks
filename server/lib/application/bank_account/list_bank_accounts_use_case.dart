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

import '../../domain/entities/bank_account.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Lists all bank accounts for an entity.
class ListBankAccountsUseCase {
  final IBankAccountRepository _repository;

  const ListBankAccountsUseCase(this._repository);

  Future<List<BankAccount>> execute({required String entityId}) async {
    await _repository.ensureCashAccount(entityId: entityId);
    return _repository.findAll(entityId: entityId);
  }
}
