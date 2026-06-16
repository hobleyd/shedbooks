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

import '../entities/general_ledger.dart';

/// Contract for general ledger persistence.
abstract interface class IGeneralLedgerRepository {
  /// Creates a new general ledger account and returns the persisted entity.
  Future<GeneralLedger> create({
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
    String? parentId,
  });

  /// Returns a general ledger account by [id] within [entityId], or null if not found / deleted.
  Future<GeneralLedger?> findById(String id, {required String entityId});

  /// Returns all active (non-deleted) general ledger accounts for [entityId].
  Future<List<GeneralLedger>> findAll({required String entityId});

  /// Updates an existing account and returns the updated entity.
  /// Throws [GeneralLedgerNotFoundException] if [id] does not exist within [entityId].
  Future<GeneralLedger> update({
    required String id,
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
    String? parentId,
  });

  /// Soft-deletes the account with [id] within [entityId].
  /// Throws [GeneralLedgerNotFoundException] if [id] does not exist within [entityId].
  /// Throws [GeneralLedgerHasChildrenException] if the account has child accounts.
  Future<void> delete(String id, {required String entityId});
}
