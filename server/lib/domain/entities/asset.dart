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

/// A club asset record in the Asset Register.
class Asset {
  /// Unique identifier (UUID v4).
  final String id;

  /// Organisation identifier from Auth0.
  final String entityId;

  /// Asset number — the business key used for reentrant import.
  final String assetNo;

  /// Asset type derived from the spreadsheet sheet name (e.g. "Wood Shop").
  final String assetType;

  /// Description of the asset.
  final String? description;

  /// Brand or manufacturer.
  final String? brand;

  /// Identification markings (e.g. asset tag).
  final String? identification;

  /// Serial number.
  final String? serialNo;

  /// Year of manufacture; null when unknown.
  final int? manufactureYear;

  /// Estimated market value stored as integer cents (value × 100).
  final int? estimatedMarketValueCents;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const Asset({
    required this.id,
    required this.entityId,
    required this.assetNo,
    required this.assetType,
    this.description,
    this.brand,
    this.identification,
    this.serialNo,
    this.manufactureYear,
    this.estimatedMarketValueCents,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Returns true when the record has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  /// Returns estimated market value as a dollar amount (cents ÷ 100), or null.
  double? get estimatedMarketValueDollars =>
      estimatedMarketValueCents != null
          ? estimatedMarketValueCents! / 100.0
          : null;
}
