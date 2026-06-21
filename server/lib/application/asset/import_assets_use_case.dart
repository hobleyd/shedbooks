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

import '../../domain/entities/asset.dart';
import '../../domain/exceptions/asset_exception.dart';
import '../../domain/repositories/i_asset_repository.dart';

/// Reentrant bulk-import of assets using UPSERT semantics.
class ImportAssetsUseCase {
  final IAssetRepository _repository;

  const ImportAssetsUseCase(this._repository);

  /// Validates and upserts [assets] for [entityId].
  ///
  /// Uses INSERT … ON CONFLICT DO UPDATE so re-importing the same spreadsheet
  /// updates existing records rather than creating duplicates.
  /// Throws [AssetValidationException] if any asset has an empty asset_no or asset_type.
  Future<List<Asset>> execute({
    required String entityId,
    required List<AssetImportData> assets,
  }) async {
    if (assets.isEmpty) return [];
    for (int i = 0; i < assets.length; i++) {
      final a = assets[i];
      if (a.assetNo.trim().isEmpty) {
        throw AssetValidationException('Item $i: asset_no must not be empty');
      }
      if (a.assetType.trim().isEmpty) {
        throw AssetValidationException('Item $i: asset_type must not be empty');
      }
    }
    final normalised = assets
        .map((a) => AssetImportData(
              assetNo: a.assetNo.trim(),
              assetType: a.assetType.trim(),
              description: a.description?.trim().isEmpty == true ? null : a.description?.trim(),
              brand: a.brand?.trim().isEmpty == true ? null : a.brand?.trim(),
              identification: a.identification?.trim().isEmpty == true ? null : a.identification?.trim(),
              serialNo: a.serialNo?.trim().isEmpty == true ? null : a.serialNo?.trim(),
              manufactureYear: a.manufactureYear,
              estimatedMarketValueCents: a.estimatedMarketValueCents,
            ))
        .toList();
    return _repository.upsertMany(entityId: entityId, assets: normalised);
  }
}
