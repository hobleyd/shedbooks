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

/// Organisation identity details returned from the API.
class EntityDetails {
  final String name;
  final String abn;
  final String incorporationIdentifier;

  /// 6-digit User ID for ABA file generation.
  final String? apcaId;

  /// Receipt format pattern for money-in transactions.
  /// `#` = digit, `@` = letter, `*` = alphanumeric, other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyInReceiptFormat;

  /// Receipt format pattern for money-out transactions.
  /// `#` = digit, `@` = letter, `*` = alphanumeric, other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyOutReceiptFormat;

  /// Format pattern for generating sequential invoice numbers.
  /// Tokens: YYYY (4-digit year), YY (2-digit year), # (sequential digit).
  /// Defaults to 'WMS-YY-###'.
  final String invoiceNumberFormat;

  /// Format pattern for generating sequential asset numbers.
  /// Tokens: YYYY (4-digit year), YY (2-digit year), {S} (Section letter),
  /// # (sequential digit). Defaults to 'YYYY-{S}-####'.
  final String assetNoFormat;

  const EntityDetails({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    this.apcaId,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
    required this.invoiceNumberFormat,
    required this.assetNoFormat,
  });

  factory EntityDetails.fromJson(Map<String, dynamic> json) => EntityDetails(
        name: json['name'] as String,
        abn: json['abn'] as String,
        incorporationIdentifier: json['incorporationIdentifier'] as String,
        apcaId: json['apcaId'] as String?,
        moneyInReceiptFormat: (json['moneyInReceiptFormat'] as String?) ?? '',
        moneyOutReceiptFormat: (json['moneyOutReceiptFormat'] as String?) ?? '',
        invoiceNumberFormat:
            (json['invoiceNumberFormat'] as String?) ?? 'WMS-YY-###',
        assetNoFormat: (json['assetNoFormat'] as String?) ?? 'YYYY-{S}-####',
      );
}
