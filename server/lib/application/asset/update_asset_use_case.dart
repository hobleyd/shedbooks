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

/// Updates an existing asset record.
class UpdateAssetUseCase {
  final IAssetRepository _repository;

  const UpdateAssetUseCase(this._repository);

  /// Validates required fields then updates and returns the [Asset].
  Future<Asset> execute({
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
  }) async {
    if (assetNo.trim().isEmpty) {
      throw const AssetValidationException('Asset number must not be empty');
    }
    if (assetType.trim().isEmpty) {
      throw const AssetValidationException('Asset type must not be empty');
    }
    return _repository.update(
      id: id,
      entityId: entityId,
      assetNo: assetNo.trim(),
      assetType: assetType.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      brand: brand?.trim().isEmpty == true ? null : brand?.trim(),
      identification: identification?.trim().isEmpty == true ? null : identification?.trim(),
      serialNo: serialNo?.trim().isEmpty == true ? null : serialNo?.trim(),
      manufactureYear: manufactureYear,
      estimatedMarketValueCents: estimatedMarketValueCents,
    );
  }
}
