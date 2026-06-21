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

import '../entities/asset.dart';

/// Contract for asset persistence.
abstract interface class IAssetRepository {
  /// Creates a new asset and returns the persisted entity.
  Future<Asset> create({
    required String entityId,
    required String assetNo,
    required String assetType,
    String? description,
    String? brand,
    String? identification,
    String? serialNo,
    int? manufactureYear,
    int? estimatedMarketValueCents,
  });

  /// Returns the asset with [id] scoped to [entityId], or null if not found.
  Future<Asset?> findById(String id, {required String entityId});

  /// Returns all active assets for [entityId], ordered by asset_type then asset_no.
  Future<List<Asset>> findAll({required String entityId});

  /// Updates the asset with [id] and returns the updated entity.
  ///
  /// Throws [StateError] if the asset does not exist or belongs to a different entity.
  Future<Asset> update({
    required String id,
    required String entityId,
    required String assetNo,
    required String assetType,
    String? description,
    String? brand,
    String? identification,
    String? serialNo,
    int? manufactureYear,
    int? estimatedMarketValueCents,
  });

  /// Soft-deletes the asset with [id].
  ///
  /// Throws [StateError] if the asset does not exist or belongs to a different entity.
  Future<void> delete(String id, {required String entityId});

  /// Upserts a list of assets within a single transaction.
  ///
  /// Uses INSERT … ON CONFLICT (entity_id, asset_no) DO UPDATE so that
  /// re-importing the same spreadsheet updates existing records rather than
  /// creating duplicates.
  Future<List<Asset>> upsertMany({
    required String entityId,
    required List<AssetImportData> assets,
  });
}

/// Data transfer object for bulk asset import.
class AssetImportData {
  final String assetNo;
  final String assetType;
  final String? description;
  final String? brand;
  final String? identification;
  final String? serialNo;
  final int? manufactureYear;
  final int? estimatedMarketValueCents;

  const AssetImportData({
    required this.assetNo,
    required this.assetType,
    this.description,
    this.brand,
    this.identification,
    this.serialNo,
    this.manufactureYear,
    this.estimatedMarketValueCents,
  });
}
