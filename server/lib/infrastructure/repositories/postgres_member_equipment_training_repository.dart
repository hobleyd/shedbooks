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

import '../../domain/entities/member_equipment_training.dart';
import '../../domain/repositories/i_member_equipment_training_repository.dart';

/// PostgreSQL implementation of [IMemberEquipmentTrainingRepository].
class PostgresMemberEquipmentTrainingRepository
    implements IMemberEquipmentTrainingRepository {
  final Pool _pool;

  const PostgresMemberEquipmentTrainingRepository(this._pool);

  static final List<String> _sections = TrainingSection.values
      .map((TrainingSection s) => s.sectionName.toLowerCase())
      .toList();

  static const String _trainingSelect = '''
    SELECT t.member_id::text AS member_id, t.trained_on,
           a.id::text AS asset_id, a.asset_no, a.asset_type,
           a.description, a.brand
    FROM member_equipment_training t
    JOIN assets a
      ON a.id = t.asset_id AND a.entity_id = t.entity_id
     AND a.deleted_at IS NULL
    JOIN members m
      ON m.id = t.member_id AND m.entity_id = t.entity_id
     AND m.deleted_at IS NULL
    WHERE t.entity_id = @entityId
      AND t.deleted_at IS NULL
  ''';

  static const String _trainingOrder =
      'ORDER BY t.member_id, a.asset_type, a.description NULLS LAST, a.asset_no';

  @override
  Future<List<TrainingEquipment>> findEquipment({
    required String entityId,
  }) async {
    final Result result = await _pool.execute(
      Sql.named('''
        SELECT id::text AS asset_id, asset_no, asset_type, description, brand
        FROM assets
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
          AND LOWER(TRIM(asset_type)) = ANY(@sections)
        ORDER BY asset_type, description NULLS LAST, asset_no
      '''),
      parameters: {
        'entityId': entityId,
        'sections': TypedValue(Type.textArray, _sections),
      },
    );
    return result.map((row) => _mapEquipment(row.toColumnMap())).toList();
  }

  @override
  Future<List<MemberEquipmentTraining>> findAll({
    required String entityId,
  }) async {
    final Result result = await _pool.execute(
      Sql.named('$_trainingSelect $_trainingOrder'),
      parameters: {'entityId': entityId},
    );
    return result.map((row) => _mapTraining(row.toColumnMap())).toList();
  }

  @override
  Future<List<MemberEquipmentTraining>> findForMember(
    String memberId, {
    required String entityId,
  }) =>
      _findForMember(_pool, memberId, entityId);

  @override
  Future<List<MemberEquipmentTraining>> replaceForMember({
    required String memberId,
    required String entityId,
    required Set<String> assetIds,
    required DateTime trainedOn,
  }) {
    final List<String> ids = assetIds.toList();
    return _pool.runTx((TxSession tx) async {
      await tx.execute(
        Sql.named('''
          UPDATE member_equipment_training
          SET deleted_at = NOW()
          WHERE entity_id = @entityId
            AND member_id = @memberId::uuid
            AND deleted_at IS NULL
            AND NOT (asset_id::text = ANY(@assetIds))
        '''),
        parameters: {
          'entityId': entityId,
          'memberId': memberId,
          'assetIds': TypedValue(Type.textArray, ids),
        },
      );
      // The assets/members sub-selects re-assert entity ownership at the
      // SQL level, so a foreign id can never be linked even if the caller
      // skipped validation.
      await tx.execute(
        Sql.named('''
          INSERT INTO member_equipment_training
            (entity_id, member_id, asset_id, trained_on)
          SELECT @entityId, m.id, a.id, @trainedOn::date
          FROM assets a
          JOIN members m
            ON m.id = @memberId::uuid AND m.entity_id = @entityId
           AND m.deleted_at IS NULL
          WHERE a.entity_id = @entityId
            AND a.deleted_at IS NULL
            AND a.id::text = ANY(@assetIds)
          ON CONFLICT (entity_id, member_id, asset_id)
            WHERE deleted_at IS NULL
            DO NOTHING
        '''),
        parameters: {
          'entityId': entityId,
          'memberId': memberId,
          'assetIds': TypedValue(Type.textArray, ids),
          'trainedOn': trainedOn.toIso8601String().substring(0, 10),
        },
      );
      return _findForMember(tx, memberId, entityId);
    });
  }

  static Future<List<MemberEquipmentTraining>> _findForMember(
    Session session,
    String memberId,
    String entityId,
  ) async {
    final Result result = await session.execute(
      Sql.named('''
        $_trainingSelect
          AND t.member_id = @memberId::uuid
        $_trainingOrder
      '''),
      parameters: {'entityId': entityId, 'memberId': memberId},
    );
    return result.map((row) => _mapTraining(row.toColumnMap())).toList();
  }

  static TrainingEquipment _mapEquipment(Map<String, dynamic> row) =>
      TrainingEquipment(
        assetId: row['asset_id'] as String,
        assetNo: row['asset_no'] as String,
        section: row['asset_type'] as String,
        description: row['description'] as String?,
        brand: row['brand'] as String?,
      );

  static MemberEquipmentTraining _mapTraining(Map<String, dynamic> row) =>
      MemberEquipmentTraining(
        memberId: row['member_id'] as String,
        equipment: _mapEquipment(row),
        trainedOn: row['trained_on'] as DateTime,
      );
}
