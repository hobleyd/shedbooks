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

/// A month that has been locked, preventing edits to transactions in that period.
class LockedMonth {
  /// Unique identifier (UUID v4).
  final String id;

  /// The Auth0 organisation ID that owns this lock.
  final String entityId;

  /// The bank account this lock applies to.
  final String bankAccountId;

  /// The locked period in YYYY-MM format (e.g. `"2026-04"`).
  final String monthYear;

  /// When the lock was applied.
  final DateTime lockedAt;

  const LockedMonth({
    required this.id,
    required this.entityId,
    required this.bankAccountId,
    required this.monthYear,
    required this.lockedAt,
  });
}
