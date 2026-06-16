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

/// A GST rate that applies from a specific date.
///
/// The applicable rate at any point in time is the record with the
/// highest [effectiveFrom] that is on or before that date.
class GstRate {
  /// Unique identifier (UUID v4).
  final String id;

  /// The rate as a decimal fraction — e.g. 0.10 represents 10%.
  final double rate;

  /// The date from which this rate applies.
  final DateTime effectiveFrom;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const GstRate({
    required this.id,
    required this.rate,
    required this.effectiveFrom,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Returns the rate as a percentage — e.g. 10.0 for a rate of 0.10.
  double get rateAsPercentage => rate * 100;
}
