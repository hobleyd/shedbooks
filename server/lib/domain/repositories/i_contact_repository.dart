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

import '../entities/contact.dart';

/// Contract for contact persistence.
abstract interface class IContactRepository {
  /// Creates a new contact and returns the persisted entity.
  Future<Contact> create({
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
    String? address,
  });

  /// Returns a contact by [id] within [entityId], or null if not found / deleted.
  Future<Contact?> findById(String id, {required String entityId});

  /// Returns all active (non-deleted) contacts for [entityId] ordered by name ascending.
  Future<List<Contact>> findAll({required String entityId});

  /// Updates an existing contact and returns the updated entity.
  /// Throws [ContactNotFoundException] if [id] does not exist within [entityId].
  Future<Contact> update({
    required String id,
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
    String? address,
  });

  /// Soft-deletes the contact with [id] within [entityId].
  /// Throws [ContactNotFoundException] if [id] does not exist within [entityId].
  Future<void> delete(String id, {required String entityId});
}
