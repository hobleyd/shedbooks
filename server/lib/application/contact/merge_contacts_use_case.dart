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

import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Merges one or more contacts into a single surviving contact.
///
/// All active transactions referencing any contact in [mergeIds] are
/// reassigned to [keepId], then those contacts are soft-deleted.
/// Returns the surviving [Contact].
class MergeContactsUseCase {
  final IContactRepository _contacts;
  final ITransactionRepository _transactions;

  const MergeContactsUseCase(this._contacts, this._transactions);

  Future<({Contact kept, List<String> mergedNames})> execute({
    required String keepId,
    required List<String> mergeIds,
    required String entityId,
  }) async {
    final kept = await _contacts.findById(keepId, entityId: entityId);
    if (kept == null) throw ContactNotFoundException(keepId);

    final mergedNames = <String>[];
    for (final id in mergeIds) {
      final contact = await _contacts.findById(id, entityId: entityId);
      if (contact == null) throw ContactNotFoundException(id);
      mergedNames.add(contact.name);
    }

    await _transactions.reassignContact(mergeIds, keepId, entityId: entityId);

    for (final id in mergeIds) {
      await _contacts.delete(id, entityId: entityId);
    }

    return (kept: kept, mergedNames: mergedNames);
  }
}
