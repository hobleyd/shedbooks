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

import '../entities/gst_rate.dart';

/// Contract for GST rate persistence.
abstract interface class IGstRateRepository {
  /// Creates a new GST rate and returns the persisted entity.
  /// Throws [GstRateDuplicateEffectiveDateException] if [effectiveFrom] is already in use within [entityId].
  Future<GstRate> create({
    required String entityId,
    required double rate,
    required DateTime effectiveFrom,
  });

  /// Returns a GST rate by [id] within [entityId], or null if not found / deleted.
  Future<GstRate?> findById(String id, {required String entityId});

  /// Returns all active (non-deleted) GST rates for [entityId], ordered by [effectiveFrom] descending.
  Future<List<GstRate>> findAll({required String entityId});

  /// Returns the rate whose [effectiveFrom] is the highest value on or before [date] for [entityId].
  /// Returns null when no rate has been defined for that date.
  Future<GstRate?> findEffectiveAt(DateTime date, {required String entityId});

  /// Updates an existing rate and returns the updated entity.
  /// Throws [GstRateNotFoundException] if [id] does not exist within [entityId].
  /// Throws [GstRateDuplicateEffectiveDateException] if the new [effectiveFrom] conflicts.
  Future<GstRate> update({
    required String id,
    required String entityId,
    required double rate,
    required DateTime effectiveFrom,
  });

  /// Soft-deletes the rate with [id] within [entityId].
  /// Throws [GstRateNotFoundException] if [id] does not exist within [entityId].
  Future<void> delete(String id, {required String entityId});
}
