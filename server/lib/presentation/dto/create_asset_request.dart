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

/// Deserialised request body for POST /assets and PUT /assets/:id.
class CreateAssetRequest {
  final String assetNo;
  final String assetType;
  final String? description;
  final String? brand;
  final String? identification;
  final String? serialNo;
  final int? manufactureYear;
  final int? estimatedMarketValueCents;

  const CreateAssetRequest({
    required this.assetNo,
    required this.assetType,
    this.description,
    this.brand,
    this.identification,
    this.serialNo,
    this.manufactureYear,
    this.estimatedMarketValueCents,
  });

  factory CreateAssetRequest.fromJson(Map<String, dynamic> json) {
    final assetNo = json['assetNo'];
    if (assetNo is! String || assetNo.trim().isEmpty) {
      throw const FormatException('assetNo must be a non-empty string');
    }
    final assetType = json['assetType'];
    if (assetType is! String || assetType.trim().isEmpty) {
      throw const FormatException('assetType must be a non-empty string');
    }
    return CreateAssetRequest(
      assetNo: assetNo,
      assetType: assetType,
      description: _optionalString(json, 'description'),
      brand: _optionalString(json, 'brand'),
      identification: _optionalString(json, 'identification'),
      serialNo: _optionalString(json, 'serialNo'),
      manufactureYear: _optionalInt(json, 'manufactureYear'),
      estimatedMarketValueCents: _optionalInt(json, 'estimatedMarketValueCents'),
    );
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final v = json[key];
    return (v is String) ? v : null;
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
