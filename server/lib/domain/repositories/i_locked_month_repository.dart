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

import '../entities/locked_month.dart';

/// Contract for [LockedMonth] persistence.
abstract interface class ILockedMonthRepository {
  /// Returns all locked months for [entityId], ordered by month_year descending.
  Future<List<LockedMonth>> findAll(String entityId);

  /// Returns `true` if [monthYear] (YYYY-MM) is locked for any bank account
  /// belonging to [entityId].
  Future<bool> isLocked(String entityId, String monthYear);

  /// Locks [monthYear] for [bankAccountId] within [entityId]. Idempotent.
  Future<void> lock(String entityId, String monthYear, String bankAccountId);

  /// Unlocks [monthYear] for [bankAccountId] within [entityId]. No-op if not locked.
  Future<void> unlock(String entityId, String monthYear, String bankAccountId);
}
