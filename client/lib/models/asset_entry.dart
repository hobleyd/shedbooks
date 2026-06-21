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

/// An asset entry returned from the API.
class AssetEntry {
  final String id;
  final String assetNo;
  final String assetType;
  final String? description;
  final String? brand;
  final String? identification;
  final String? serialNo;
  final int? manufactureYear;

  /// Estimated market value in cents (value × 100).
  final int? estimatedMarketValueCents;

  const AssetEntry({
    required this.id,
    required this.assetNo,
    required this.assetType,
    this.description,
    this.brand,
    this.identification,
    this.serialNo,
    this.manufactureYear,
    this.estimatedMarketValueCents,
  });

  /// Returns estimated market value as an integer dollar amount (cents ÷ 100), or null.
  int? get estimatedMarketValueDollars =>
      estimatedMarketValueCents != null ? estimatedMarketValueCents! ~/ 100 : null;

  factory AssetEntry.fromJson(Map<String, dynamic> json) {
    return AssetEntry(
      id: json['id'] as String,
      assetNo: json['assetNo'] as String,
      assetType: json['assetType'] as String,
      description: json['description'] as String?,
      brand: json['brand'] as String?,
      identification: json['identification'] as String?,
      serialNo: json['serialNo'] as String?,
      manufactureYear: json['manufactureYear'] as int?,
      estimatedMarketValueCents: json['estimatedMarketValueCents'] == null
          ? null
          : (json['estimatedMarketValueCents'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'assetNo': assetNo,
        'assetType': assetType,
        'description': description,
        'brand': brand,
        'identification': identification,
        'serialNo': serialNo,
        'manufactureYear': manufactureYear,
        'estimatedMarketValueCents': estimatedMarketValueCents,
      };
}
