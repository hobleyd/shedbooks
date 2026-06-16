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

import '../../domain/exceptions/bank_account_exception.dart';
import '../../domain/repositories/i_bank_account_repository.dart';

/// Soft-deletes a bank account.
class DeleteBankAccountUseCase {
  final IBankAccountRepository _repository;

  const DeleteBankAccountUseCase(this._repository);

  /// Throws [BankAccountNotFoundException] when the account does not exist.
  Future<void> execute(String id, {required String entityId}) async {
    final account = await _repository.findById(id, entityId: entityId);
    if (account == null) throw BankAccountNotFoundException(id);
    await _repository.delete(id, entityId: entityId);
  }
}
