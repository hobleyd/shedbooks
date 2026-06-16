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

import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Soft-deletes a contact.
///
/// Throws [ContactInUseException] if any active transaction references the contact.
class DeleteContactUseCase {
  final IContactRepository _repository;
  final ITransactionRepository _transactions;

  const DeleteContactUseCase(this._repository, this._transactions);

  Future<void> execute(String id, {required String entityId}) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw ContactNotFoundException(id);
    if (await _transactions.hasTransactions(id, entityId: entityId)) {
      throw ContactInUseException(id);
    }
    await _repository.delete(id, entityId: entityId);
  }
}
