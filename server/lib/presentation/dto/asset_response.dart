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

import 'dart:convert';

import '../../domain/entities/asset.dart';

/// JSON response shape for an asset.
class AssetResponse {
  final String id;
  final String assetNo;
  final String assetType;
  final String? description;
  final String? brand;
  final String? identification;
  final String? serialNo;
  final int? manufactureYear;
  final int? estimatedMarketValueCents;
  final String createdAt;
  final String updatedAt;

  const AssetResponse({
    required this.id,
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
  });

  factory AssetResponse.fromEntity(Asset entity) => AssetResponse(
        id: entity.id,
        assetNo: entity.assetNo,
        assetType: entity.assetType,
        description: entity.description,
        brand: entity.brand,
        identification: entity.identification,
        serialNo: entity.serialNo,
        manufactureYear: entity.manufactureYear,
        estimatedMarketValueCents: entity.estimatedMarketValueCents,
        createdAt: entity.createdAt.toUtc().toIso8601String(),
        updatedAt: entity.updatedAt.toUtc().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetNo': assetNo,
        'assetType': assetType,
        'description': description,
        'brand': brand,
        'identification': identification,
        'serialNo': serialNo,
        'manufactureYear': manufactureYear,
        'estimatedMarketValueCents': estimatedMarketValueCents,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
