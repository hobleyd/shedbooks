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

/// A month that has been locked against transaction edits for a specific bank account.
class LockedMonthEntry {
  /// The locked period in YYYY-MM format (e.g. `"2026-04"`).
  final String monthYear;

  /// The bank account this lock applies to.
  final String bankAccountId;

  /// When the lock was applied.
  final DateTime lockedAt;

  const LockedMonthEntry({
    required this.monthYear,
    required this.bankAccountId,
    required this.lockedAt,
  });

  factory LockedMonthEntry.fromJson(Map<String, dynamic> json) =>
      LockedMonthEntry(
        monthYear: json['monthYear'] as String,
        bankAccountId: json['bankAccountId'] as String,
        lockedAt: DateTime.parse(json['lockedAt'] as String),
      );
}
