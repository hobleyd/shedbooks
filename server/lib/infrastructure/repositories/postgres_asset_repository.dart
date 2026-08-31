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

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/asset.dart';
import '../../domain/exceptions/asset_exception.dart';
import '../../domain/repositories/i_asset_repository.dart';

/// PostgreSQL implementation of [IAssetRepository].
class PostgresAssetRepository implements IAssetRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresAssetRepository(this._pool, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  static const _cols =
      'id, entity_id, asset_no, asset_type, description, brand, '
      'identification, serial_no, manufacture_year, '
      'estimated_market_value_cents, created_at, updated_at, deleted_at';

  @override
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
  }) async {
    final id = _uuid.v4();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO assets
          (id, entity_id, asset_no, asset_type, description, brand,
           identification, serial_no, manufacture_year,
           estimated_market_value_cents)
        VALUES (
          @id::uuid, @entityId, @assetNo, @assetType, @description, @brand,
          @identification, @serialNo, @manufactureYear,
          @estimatedMarketValueCents
        )
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'assetNo': assetNo,
        'assetType': assetType,
        'description': description,
        'brand': brand,
        'identification': identification,
        'serialNo': serialNo,
        'manufactureYear': manufactureYear,
        'estimatedMarketValueCents': estimatedMarketValueCents,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<Asset?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols FROM assets
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<Asset>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols FROM assets
        WHERE entity_id = @entityId AND deleted_at IS NULL
        ORDER BY asset_type ASC, asset_no ASC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((r) => _mapRow(r.toColumnMap())).toList();
  }

  @override
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
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE assets
        SET asset_no                      = @assetNo,
            asset_type                    = @assetType,
            description                   = @description,
            brand                         = @brand,
            identification                = @identification,
            serial_no                     = @serialNo,
            manufacture_year              = @manufactureYear,
            estimated_market_value_cents  = @estimatedMarketValueCents,
            updated_at                    = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'assetNo': assetNo,
        'assetType': assetType,
        'description': description,
        'brand': brand,
        'identification': identification,
        'serialNo': serialNo,
        'manufactureYear': manufactureYear,
        'estimatedMarketValueCents': estimatedMarketValueCents,
      },
    );
    if (result.isEmpty) throw AssetNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE assets
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.affectedRows == 0) throw AssetNotFoundException(id);
  }

  @override
  Future<List<Asset>> upsertMany({
    required String entityId,
    required List<AssetImportData> assets,
  }) async {
    final results = <Asset>[];
    await _pool.runTx((tx) async {
      for (final a in assets) {
        final id = _uuid.v4();
        final rows = await tx.execute(
          Sql.named('''
            INSERT INTO assets
              (id, entity_id, asset_no, asset_type, description, brand,
               identification, serial_no, manufacture_year,
               estimated_market_value_cents)
            VALUES (
              @id::uuid, @entityId, @assetNo, @assetType, @description, @brand,
              @identification, @serialNo, @manufactureYear,
              @estimatedMarketValueCents
            )
            ON CONFLICT (entity_id, asset_no) DO UPDATE
              SET asset_type                    = EXCLUDED.asset_type,
                  description                   = EXCLUDED.description,
                  brand                         = EXCLUDED.brand,
                  identification                = EXCLUDED.identification,
                  serial_no                     = EXCLUDED.serial_no,
                  manufacture_year              = EXCLUDED.manufacture_year,
                  estimated_market_value_cents  = EXCLUDED.estimated_market_value_cents,
                  deleted_at                    = NULL,
                  updated_at                    = NOW()
            RETURNING $_cols
          '''),
          parameters: {
            'id': id,
            'entityId': entityId,
            'assetNo': a.assetNo,
            'assetType': a.assetType,
            'description': a.description,
            'brand': a.brand,
            'identification': a.identification,
            'serialNo': a.serialNo,
            'manufactureYear': a.manufactureYear,
            'estimatedMarketValueCents': a.estimatedMarketValueCents,
          },
        );
        results.add(_mapRow(rows.first.toColumnMap()));
      }
    });
    return results;
  }

  @override
  Future<List<String>> findAssetNosLike(String pattern,
      {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT DISTINCT asset_no
        FROM assets
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
          AND asset_no LIKE @pattern
      '''),
      parameters: {'entityId': entityId, 'pattern': pattern},
    );
    return result.map((r) => r[0] as String).toList();
  }

  @override
  Future<List<String>> findDistinctSections({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT DISTINCT asset_type
        FROM assets
        WHERE entity_id = @entityId AND deleted_at IS NULL
        ORDER BY asset_type ASC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((r) => r[0] as String).toList();
  }

  static Asset _mapRow(Map<String, dynamic> row) => Asset(
        id: row['id'].toString(),
        entityId: row['entity_id'] as String,
        assetNo: row['asset_no'] as String,
        assetType: row['asset_type'] as String,
        description: row['description'] as String?,
        brand: row['brand'] as String?,
        identification: row['identification'] as String?,
        serialNo: row['serial_no'] as String?,
        manufactureYear: row['manufacture_year'] as int?,
        estimatedMarketValueCents: row['estimated_market_value_cents'] == null
            ? null
            : (row['estimated_market_value_cents'] as num).toInt(),
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
        deletedAt: row['deleted_at'] as DateTime?,
      );
}
