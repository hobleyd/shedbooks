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

// Integration test — runs against a real PostgreSQL database and is skipped
// unless TEST_DB_HOST is set. See
// postgres_transaction_repository_split_test.dart for how to start a
// throwaway container.
//
// Never point it at a database holding real data: it applies every migration
// and writes rows it does not clean up.

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/member_equipment_training.dart';
import 'package:shedbooks_server/infrastructure/database/database_migrator.dart';
import 'package:shedbooks_server/infrastructure/repositories/postgres_member_equipment_training_repository.dart';

void main() {
  final String? host = Platform.environment['TEST_DB_HOST'];

  group('PostgresMemberEquipmentTrainingRepository', () {
    late Pool pool;
    late PostgresMemberEquipmentTrainingRepository sut;
    late String tEntityId;
    late String tOtherEntityId;
    late String saw;
    late String drill;
    late String lathe;
    late String desk;
    late String otherEntitySaw;
    int memberSeq = 0;

    Future<String> insertReturningId(String sql, Map<String, dynamic> params) async {
      final Result result = await pool.execute(Sql.named(sql), parameters: params);
      return result.first.toColumnMap()['id'].toString();
    }

    Future<String> insertAsset(String entityId, String no, String section, String description) =>
        insertReturningId(
          'INSERT INTO assets (entity_id, asset_no, asset_type, description) '
          'VALUES (@e, @no, @type, @desc) RETURNING id',
          {'e': entityId, 'no': no, 'type': section, 'desc': description},
        );

    Future<String> insertMember({String? entityId}) => insertReturningId(
          'INSERT INTO members (entity_id, first_name, last_name) '
          "VALUES (@e, 'Test', @last) RETURNING id",
          {'e': entityId ?? tEntityId, 'last': 'Member ${++memberSeq}'},
        );

    Map<String, String> dates(List<MemberEquipmentTraining> training) => {
          for (final MemberEquipmentTraining t in training)
            t.equipment.assetId: t.trainedOn.toIso8601String().substring(0, 10),
        };

    setUpAll(() async {
      pool = Pool.withEndpoints(
        [
          Endpoint(
            host: host!,
            port: int.parse(Platform.environment['TEST_DB_PORT'] ?? '5432'),
            database: Platform.environment['TEST_DB_NAME'] ?? 'shedbooks_test',
            username: Platform.environment['TEST_DB_USER'] ?? 'shedbooks',
            password: Platform.environment['TEST_DB_PASSWORD'],
          ),
        ],
        settings: const PoolSettings(maxConnectionCount: 4, sslMode: SslMode.disable),
      );
      await DatabaseMigrator(pool).migrate();
      sut = PostgresMemberEquipmentTrainingRepository(pool);

      // Unique per run — the test database is not cleaned between runs.
      final int run = DateTime.now().microsecondsSinceEpoch;
      tEntityId = 'training-it-$run';
      tOtherEntityId = 'training-it-other-$run';
      saw = await insertAsset(tEntityId, 'W-1', 'Wood Shop', 'Band Saw');
      drill = await insertAsset(tEntityId, 'W-2', ' wood shop ', 'Drill Press');
      lathe = await insertAsset(tEntityId, 'M-1', 'METAL SHOP', 'Lathe');
      desk = await insertAsset(tEntityId, 'O-1', 'Office', 'Desk');
      otherEntitySaw = await insertAsset(tOtherEntityId, 'W-1', 'Wood Shop', 'Other Saw');
    });

    tearDownAll(() async {
      await pool.close();
    });

    test('findEquipment returns only the entity\'s Wood/Metal Shop assets, '
        'matching the Section ignoring case and surrounding space', () async {
      // Act
      final List<TrainingEquipment> result = await sut.findEquipment(entityId: tEntityId);

      // Assert
      expect(result.map((e) => e.assetId), unorderedEquals([saw, drill, lathe]));
      expect(result.map((e) => e.assetId), isNot(contains(desk)));
      expect(result.map((e) => e.assetId), isNot(contains(otherEntitySaw)));
    });

    test('replaceForMember records newly listed equipment with trainedOn', () async {
      // Arrange
      final String member = await insertMember();

      // Act
      final result = await sut.replaceForMember(
        memberId: member,
        entityId: tEntityId,
        assetIds: {saw, lathe},
        trainedOn: DateTime.utc(2026, 10, 1),
      );

      // Assert
      expect(dates(result), {saw: '2026-10-01', lathe: '2026-10-01'});
      expect(result.firstWhere((t) => t.equipment.assetId == saw).equipment.description,
          'Band Saw');
    });

    test('a later save keeps the original date of equipment still listed, '
        'dates new equipment, and removes unlisted equipment', () async {
      // Arrange
      final String member = await insertMember();
      await sut.replaceForMember(
        memberId: member,
        entityId: tEntityId,
        assetIds: {saw, lathe},
        trainedOn: DateTime.utc(2026, 10, 1),
      );

      // Act
      final result = await sut.replaceForMember(
        memberId: member,
        entityId: tEntityId,
        assetIds: {saw, drill},
        trainedOn: DateTime.utc(2026, 10, 8),
      );

      // Assert
      expect(dates(result), {saw: '2026-10-01', drill: '2026-10-08'});
    });

    test('re-listing previously removed equipment records the new date', () async {
      // Arrange
      final String member = await insertMember();
      Future<List<MemberEquipmentTraining>> save(Set<String> ids, int day) =>
          sut.replaceForMember(
            memberId: member,
            entityId: tEntityId,
            assetIds: ids,
            trainedOn: DateTime.utc(2026, 10, day),
          );
      await save({saw}, 1);
      await save({}, 2);

      // Act
      final result = await save({saw}, 15);

      // Assert
      expect(dates(result), {saw: '2026-10-15'});
    });

    test('an empty set clears the member\'s training', () async {
      // Arrange
      final String member = await insertMember();
      await sut.replaceForMember(
        memberId: member,
        entityId: tEntityId,
        assetIds: {saw},
        trainedOn: DateTime.utc(2026, 10, 1),
      );

      // Act
      final result = await sut.replaceForMember(
        memberId: member,
        entityId: tEntityId,
        assetIds: {},
        trainedOn: DateTime.utc(2026, 10, 2),
      );

      // Assert
      expect(result, isEmpty);
      expect(await sut.findForMember(member, entityId: tEntityId), isEmpty);
    });

    test('never links an asset or member belonging to another entity', () async {
      // Arrange
      final String member = await insertMember();
      final String otherEntityMember = await insertMember(entityId: tOtherEntityId);

      // Act
      final foreignAsset = await sut.replaceForMember(
        memberId: member,
        entityId: tEntityId,
        assetIds: {otherEntitySaw},
        trainedOn: DateTime.utc(2026, 10, 1),
      );
      final foreignMember = await sut.replaceForMember(
        memberId: otherEntityMember,
        entityId: tEntityId,
        assetIds: {saw},
        trainedOn: DateTime.utc(2026, 10, 1),
      );

      // Assert
      expect(foreignAsset, isEmpty);
      expect(foreignMember, isEmpty);
      expect(await sut.findForMember(otherEntityMember, entityId: tOtherEntityId), isEmpty);
    });

    test('findAll returns the entity\'s records and hides those of deleted '
        'members and deleted assets', () async {
      // Arrange
      final String kept = await insertMember();
      final String deleted = await insertMember();
      final String grinder = await insertAsset(
          tEntityId, 'M-${++memberSeq}', 'Metal Shop', 'Grinder');
      await sut.replaceForMember(
        memberId: kept,
        entityId: tEntityId,
        assetIds: {saw, grinder},
        trainedOn: DateTime.utc(2026, 10, 1),
      );
      await sut.replaceForMember(
        memberId: deleted,
        entityId: tEntityId,
        assetIds: {saw},
        trainedOn: DateTime.utc(2026, 10, 1),
      );
      await pool.execute(
        Sql.named('UPDATE members SET deleted_at = NOW() WHERE id = @id::uuid'),
        parameters: {'id': deleted},
      );
      await pool.execute(
        Sql.named('UPDATE assets SET deleted_at = NOW() WHERE id = @id::uuid'),
        parameters: {'id': grinder},
      );

      // Act
      final List<MemberEquipmentTraining> all = await sut.findAll(entityId: tEntityId);

      // Assert
      expect(all.where((t) => t.memberId == deleted), isEmpty);
      expect(dates(all.where((t) => t.memberId == kept).toList()), {saw: '2026-10-01'});
      expect(await sut.findAll(entityId: tOtherEntityId), isEmpty);
    });
  }, skip: host == null ? 'TEST_DB_HOST not set — needs a real PostgreSQL database' : null);
}
