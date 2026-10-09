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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/member/create_member_use_case.dart';
import 'package:shedbooks_server/application/member/delete_member_use_case.dart';
import 'package:shedbooks_server/application/member/get_member_use_case.dart';
import 'package:shedbooks_server/application/member/import_members_use_case.dart';
import 'package:shedbooks_server/application/member/list_member_equipment_training_use_case.dart';
import 'package:shedbooks_server/application/member/list_members_use_case.dart';
import 'package:shedbooks_server/application/member/list_training_equipment_use_case.dart';
import 'package:shedbooks_server/application/member/set_member_equipment_training_use_case.dart';
import 'package:shedbooks_server/application/member/update_member_use_case.dart';
import 'package:shedbooks_server/application/o365/create_member_mailbox_use_case.dart';
import 'package:shedbooks_server/application/o365/list_available_o365_licenses_use_case.dart';
import 'package:shedbooks_server/application/o365/set_member_app_role_use_case.dart';
import 'package:shedbooks_server/application/o365/sync_members_to_o365_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';
import 'package:shedbooks_server/infrastructure/database/database_migrator.dart';
import 'package:shedbooks_server/infrastructure/encryption/backup_crypto.dart';
import 'package:shedbooks_server/infrastructure/repositories/postgres_member_equipment_training_repository.dart';
import 'package:shedbooks_server/presentation/handlers/backup_handler.dart';
import 'package:shedbooks_server/presentation/handlers/member_handler.dart';
import 'package:shedbooks_server/presentation/middleware/audit_middleware.dart';

class _MockMemberRepository extends Mock implements IMemberRepository {}

class _MockCreate extends Mock implements CreateMemberUseCase {}

class _MockGet extends Mock implements GetMemberUseCase {}

class _MockList extends Mock implements ListMembersUseCase {}

class _MockUpdate extends Mock implements UpdateMemberUseCase {}

class _MockDelete extends Mock implements DeleteMemberUseCase {}

class _MockImport extends Mock implements ImportMembersUseCase {}

class _MockSync extends Mock implements SyncMembersToO365UseCase {}

class _MockLicenses extends Mock implements ListAvailableO365LicensesUseCase {}

class _MockMailbox extends Mock implements CreateMemberMailboxUseCase {}

class _MockAppRole extends Mock implements SetMemberAppRoleUseCase {}

void main() {
  final String? host = Platform.environment['TEST_DB_HOST'];

  group('Member equipment training — backup/restore and audit log', () {
    late Pool pool;
    late PostgresMemberEquipmentTrainingRepository training;
    late String tEntityId;
    late String memberId;
    late String saw;
    late String drill;

    Map<String, Object> authContext() => {
          'auth.claims': <String, dynamic>{
            'https://shedbooks.com/entity_id': tEntityId,
            'sub': 'user-1',
            'email': 'admin@example.org',
          },
        };

    Future<String> insertReturningId(String sql, Map<String, dynamic> params) async {
      final Result result = await pool.execute(Sql.named(sql), parameters: params);
      return result.first.toColumnMap()['id'].toString();
    }

    Future<List<Map<String, dynamic>>> rows(String sql) async {
      final Result result =
          await pool.execute(Sql.named(sql), parameters: {'e': tEntityId});
      return result.map((r) => r.toColumnMap()).toList();
    }

    Future<Map<String, String>> activeTraining() async => {
          for (final t in await training.findForMember(memberId, entityId: tEntityId))
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
      training = PostgresMemberEquipmentTrainingRepository(pool);
    });

    setUp(() async {
      // A fresh entity per test — the test database is not cleaned.
      tEntityId = 'training-bk-${DateTime.now().microsecondsSinceEpoch}';
      memberId = await insertReturningId(
        "INSERT INTO members (entity_id, first_name, last_name) "
        "VALUES (@e, 'Ada', 'Lovelace') RETURNING id",
        {'e': tEntityId},
      );
      Future<String> asset(String no, String description) => insertReturningId(
            "INSERT INTO assets (entity_id, asset_no, asset_type, description) "
            "VALUES (@e, @no, 'Wood Shop', @d) RETURNING id",
            {'e': tEntityId, 'no': no, 'd': description},
          );
      saw = await asset('W-1', 'Band Saw');
      drill = await asset('W-2', 'Drill Press');
    });

    tearDownAll(() async {
      await pool.close();
    });

    group('backup and restore', () {
      late BackupHandler sut;

      Future<Uint8List> backup() async {
        final Response res = await sut.handleBackup(Request(
          'GET',
          Uri.parse('http://localhost/admin/backup'),
          context: authContext(),
        ));
        expect(res.statusCode, 200);
        return Uint8List.fromList(await res.read().expand((c) => c).toList());
      }

      Future<Response> restore(List<int> bytes) => sut.handleRestore(Request(
            'POST',
            Uri.parse('http://localhost/admin/restore'),
            body: bytes,
            context: authContext(),
          ));

      setUp(() => sut = BackupHandler(pool: pool));

      test('a restore brings back training rows exactly as backed up — '
          'dates, member/asset links and soft-deleted rows', () async {
        // Arrange — saw kept from 1 Oct; drill ticked then un-ticked.
        await training.replaceForMember(
          memberId: memberId,
          entityId: tEntityId,
          assetIds: {saw, drill},
          trainedOn: DateTime.utc(2026, 10, 1),
        );
        await training.replaceForMember(
          memberId: memberId,
          entityId: tEntityId,
          assetIds: {saw},
          trainedOn: DateTime.utc(2026, 10, 8),
        );
        const String allRows =
            'SELECT id::text, member_id::text, asset_id::text, '
            'trained_on::text, created_at, deleted_at '
            'FROM member_equipment_training WHERE entity_id = @e ORDER BY id';
        final List<Map<String, dynamic>> before = await rows(allRows);
        final Uint8List bytes = await backup();
        // Diverge from the backup: drop the saw, add the drill again.
        await training.replaceForMember(
          memberId: memberId,
          entityId: tEntityId,
          assetIds: {drill},
          trainedOn: DateTime.utc(2026, 10, 9),
        );

        // Act
        final Response res = await restore(bytes);

        // Assert
        expect(res.statusCode, 200, reason: await res.readAsString());
        expect(before, hasLength(2));
        expect(await rows(allRows), equals(before));
        expect(await activeTraining(), {saw: '2026-10-01'});
      });

      test('a backup taken before the training table existed still restores '
          '(and leaves the member with no training)', () async {
        // Arrange
        await training.replaceForMember(
          memberId: memberId,
          entityId: tEntityId,
          assetIds: {saw},
          trainedOn: DateTime.utc(2026, 10, 1),
        );
        final Map<String, dynamic> legacy = jsonDecode(utf8.decode(
          BackupCrypto(Platform.environment['BACKUP_KEY'] ??
                  'shedbooks-backup-default-key-v1')
              .decryptAndDecompress(await backup()),
        )) as Map<String, dynamic>;
        expect(legacy['member_equipment_training'], hasLength(1));
        legacy.remove('member_equipment_training');

        // Act — plain JSON is accepted as a legacy backup.
        final Response res = await restore(utf8.encode(jsonEncode(legacy)));

        // Assert
        expect(res.statusCode, 200, reason: await res.readAsString());
        expect(await rows('SELECT id FROM members WHERE entity_id = @e'), hasLength(1));
        expect(await rows('SELECT id FROM assets WHERE entity_id = @e'), hasLength(2));
        expect(await activeTraining(), isEmpty);
      });
    });

    group('audit log', () {
      late Handler pipeline;

      /// Audit inserts are fire-and-forget, so poll briefly for them.
      Future<List<Map<String, dynamic>>> auditRows({required int expecting}) async {
        List<Map<String, dynamic>> found = [];
        for (int i = 0; i < 40; i++) {
          found = await rows(
            'SELECT method, path, action, table_name, record_id, user_email, '
            'status_code, changes FROM audit_log WHERE entity_id = @e ORDER BY created_at',
          );
          if (found.length >= expecting) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        return found;
      }

      Map<String, dynamic> changesOf(Map<String, dynamic> row) {
        final Object? raw = row['changes'];
        return (raw is String ? jsonDecode(raw) : raw) as Map<String, dynamic>;
      }

      Future<Response> put(Set<String> assetIds) async => pipeline(Request(
            'PUT',
            Uri.parse('http://localhost/members/$memberId/equipment-training'),
            body: jsonEncode({'assetIds': assetIds.toList(), 'trainedOn': '2026-10-08'}),
          ));

      setUp(() {
        final _MockMemberRepository members = _MockMemberRepository();
        when(() => members.findById(memberId, entityId: tEntityId)).thenAnswer(
          (_) async => Member(
            id: memberId,
            entityId: tEntityId,
            firstName: 'Ada',
            lastName: 'Lovelace',
            etag: 'e',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );
        final MemberHandler handler = MemberHandler(
          create: _MockCreate(),
          get: _MockGet(),
          list: _MockList(),
          update: _MockUpdate(),
          delete: _MockDelete(),
          import: _MockImport(),
          syncO365: _MockSync(),
          availableLicenses: _MockLicenses(),
          createMailbox: _MockMailbox(),
          setAppRole: _MockAppRole(),
          trainingEquipment: ListTrainingEquipmentUseCase(training),
          listTraining: ListMemberEquipmentTrainingUseCase(training),
          setTraining: SetMemberEquipmentTrainingUseCase(members, training),
        );
        // Same order as the router: auth → audit → handler.
        pipeline = const Pipeline()
            .addMiddleware((Handler inner) => (Request r) =>
                inner(r.change(context: {...r.context, ...authContext()})))
            .addMiddleware(auditMiddleware(pool))
            .addHandler((Request r) => r.method == 'GET'
                ? handler.handleTrainingEquipment(r)
                : handler.handleSetEquipmentTraining(r, memberId));
      });

      test('saving training writes an UPDATE entry against members with the '
          'member and the before/after equipment', () async {
        // Act
        final Response res = await put({saw});

        // Assert
        expect(res.statusCode, 200, reason: await res.readAsString());
        final List<Map<String, dynamic>> audit = await auditRows(expecting: 1);
        expect(audit, hasLength(1));
        expect(audit.single['action'], 'UPDATE');
        expect(audit.single['table_name'], 'members');
        expect(audit.single['record_id'], isNull);
        expect(audit.single['user_email'], 'admin@example.org');
        expect(audit.single['path'], '/members/$memberId/equipment-training');
        final Map<String, dynamic> changes = changesOf(audit.single);
        expect(changes['memberId'], memberId);
        expect(changes['equipmentTraining'],
            {'from': '', 'to': 'W-1 Band Saw (2026-10-08)'});
      });

      test('a rejected save and the equipment list read are not audited', () async {
        // Act
        final Response rejected =
            await put({'00000000-0000-0000-0000-00000000dead'});
        final Response read = await pipeline(Request(
            'GET', Uri.parse('http://localhost/members/training-equipment')));
        final Response saved = await put({saw, drill});

        // Assert — only the successful save is logged.
        expect(rejected.statusCode, 400);
        expect(read.statusCode, 200);
        expect(saved.statusCode, 200);
        final List<Map<String, dynamic>> audit = await auditRows(expecting: 1);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(await auditRows(expecting: 1), hasLength(1));
        expect(audit.single['status_code'], 200);
      });
    });
  }, skip: host == null ? 'TEST_DB_HOST not set — needs a real PostgreSQL database' : null);
}
