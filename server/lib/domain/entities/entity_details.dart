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

/// Organisation identity details for an entity (tenant).
class EntityDetails {
  final String entityId;
  final String name;
  final String abn;
  final String incorporationIdentifier;

  /// 6-digit User ID assigned by the bank for ABA file generation.
  final String? apcaId;

  /// Receipt number format pattern for money-in transactions.
  /// Uses `#` (digit), `@` (letter), `*` (alphanumeric); other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyInReceiptFormat;

  /// Receipt number format pattern for money-out transactions.
  /// Uses `#` (digit), `@` (letter), `*` (alphanumeric); other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyOutReceiptFormat;

  final DateTime createdAt;
  final DateTime updatedAt;

  const EntityDetails({
    required this.entityId,
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    this.apcaId,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
    required this.createdAt,
    required this.updatedAt,
  });
}
