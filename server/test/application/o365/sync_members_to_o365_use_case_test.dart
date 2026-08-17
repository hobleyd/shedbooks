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

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/o365/sync_members_to_o365_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_o365_sync_settings_repository.dart';
import 'package:shedbooks_server/domain/services/i_o365_contact_sync_service.dart';

class MockO365SyncSettingsRepository extends Mock
    implements IO365SyncSettingsRepository {}

class MockMemberRepository extends Mock implements IMemberRepository {}

class MockO365ContactSyncService extends Mock
    implements IO365ContactSyncService {}

void main() {
  late MockO365SyncSettingsRepository settingsRepository;
  late MockMemberRepository memberRepository;
  late MockO365ContactSyncService syncService;
  late SyncMembersToO365UseCase sut;

  const tEntityId = 'entity-1';
  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'tenant-guid',
    clientId: 'client-guid',
    certificatePfxBase64: 'ZmFrZS1wZng=',
    certificatePassword: 'secret',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Member member(String id) => Member(
        id: id,
        entityId: tEntityId,
        firstName: 'Ron',
        lastName: 'Anderson $id',
        email: 'ron$id@example.com',
        etag: 'etag-$id',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(tSettings);
    registerFallbackValue(<Member>[]);
  });

  setUp(() {
    settingsRepository = MockO365SyncSettingsRepository();
    memberRepository = MockMemberRepository();
    syncService = MockO365ContactSyncService();
    sut = SyncMembersToO365UseCase(
      settingsRepository,
      memberRepository,
      syncService,
    );
    when(() => settingsRepository.markInitialSyncCompleted(tEntityId))
        .thenAnswer((_) async {});
    when(() => memberRepository.markO365Synced(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          o365ContactId: any(named: 'o365ContactId'),
        )).thenAnswer((_) async {});
    when(() => memberRepository.markO365SyncFailed(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
        )).thenAnswer((_) async {});
  });

  group('SyncMembersToO365UseCase', () {
    test('throws O365SyncNotConfiguredException when settings are missing',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(entityId: tEntityId),
        throwsA(isA<O365SyncNotConfiguredException>()),
      );
      verifyNever(() => memberRepository.findPendingO365Sync(
          entityId: any(named: 'entityId'), limit: any(named: 'limit')));
    });

    test('marks the entity as having completed its first sync run',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findPendingO365Sync(
          entityId: tEntityId, limit: any(named: 'limit'))).thenAnswer(
          (_) async => []);
      when(() => memberRepository.countPendingO365Sync(entityId: tEntityId))
          .thenAnswer((_) async => 0);
      when(() => memberRepository.countUnsyncableForO365Sync(
          entityId: tEntityId)).thenAnswer((_) async => 0);

      // Act
      await sut.execute(entityId: tEntityId);

      // Assert
      verify(() => settingsRepository.markInitialSyncCompleted(tEntityId))
          .called(1);
    });

    test('does not call the sync service when there is nothing pending',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findPendingO365Sync(
          entityId: tEntityId,
          limit: any(named: 'limit'))).thenAnswer((_) async => []);
      when(() => memberRepository.countPendingO365Sync(entityId: tEntityId))
          .thenAnswer((_) async => 0);
      when(() => memberRepository.countUnsyncableForO365Sync(
          entityId: tEntityId)).thenAnswer((_) async => 0);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result.synced, equals(0));
      verifyNever(() => syncService.upsertContacts(
          settings: any(named: 'settings'), members: any(named: 'members')));
    });

    test('surfaces the count of members that can never sync due to a missing or invalid email',
        () async {
      // Arrange — this is the batch-selection fix: members without a
      // syncable email (missing, or not even the basic shape of one, e.g.
      // "N/A") are excluded from findPendingO365Sync/countPendingO365Sync
      // entirely (so they never permanently occupy a batch slot ahead of
      // syncable members), but still counted separately so the admin can
      // see why.
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findPendingO365Sync(
          entityId: tEntityId,
          limit: any(named: 'limit'))).thenAnswer((_) async => []);
      when(() => memberRepository.countPendingO365Sync(entityId: tEntityId))
          .thenAnswer((_) async => 0);
      when(() => memberRepository.countUnsyncableForO365Sync(
          entityId: tEntityId)).thenAnswer((_) async => 5);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result.unsyncableEmail, equals(5));
    });

    test('syncs the whole pending batch in one call and marks each synced',
        () async {
      // Arrange
      final m1 = member('1');
      final m2 = member('2');
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findPendingO365Sync(
          entityId: tEntityId,
          limit: any(named: 'limit'))).thenAnswer((_) async => [m1, m2]);
      when(() => syncService.upsertContacts(
          settings: tSettings, members: [m1, m2])).thenAnswer((_) async => [
            O365ContactSyncResult(memberId: '1', contactId: 'gal-id-1'),
            O365ContactSyncResult(memberId: '2', contactId: 'gal-id-2'),
          ]);
      when(() => memberRepository.countPendingO365Sync(entityId: tEntityId))
          .thenAnswer((_) async => 0);
      when(() => memberRepository.countUnsyncableForO365Sync(
          entityId: tEntityId)).thenAnswer((_) async => 0);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result.synced, equals(2));
      expect(result.failed, equals(0));
      expect(result.remaining, equals(0));
      verify(() => memberRepository.markO365Synced(
          id: '1', entityId: tEntityId, o365ContactId: 'gal-id-1')).called(1);
      verify(() => memberRepository.markO365Synced(
          id: '2', entityId: tEntityId, o365ContactId: 'gal-id-2')).called(1);
    });

    test('counts a per-member failure without marking it synced', () async {
      // Arrange
      final m1 = member('1');
      final m2 = member('2');
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findPendingO365Sync(
          entityId: tEntityId,
          limit: any(named: 'limit'))).thenAnswer((_) async => [m1, m2]);
      when(() => syncService.upsertContacts(
          settings: tSettings, members: [m1, m2])).thenAnswer((_) async => [
            O365ContactSyncResult(
              memberId: '1',
              error: const O365ContactSyncException('no email address'),
            ),
            O365ContactSyncResult(memberId: '2', contactId: 'gal-id-2'),
          ]);
      when(() => memberRepository.countPendingO365Sync(entityId: tEntityId))
          .thenAnswer((_) async => 1);
      when(() => memberRepository.countUnsyncableForO365Sync(
          entityId: tEntityId)).thenAnswer((_) async => 0);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result.synced, equals(1));
      expect(result.failed, equals(1));
      expect(result.remaining, equals(1));
      verifyNever(() => memberRepository.markO365Synced(
          id: '1',
          entityId: any(named: 'entityId'),
          o365ContactId: any(named: 'o365ContactId')));
      // The batch-starvation fix: a failed member is marked so the next
      // batch query deprioritizes it behind never-attempted members.
      verify(() => memberRepository.markO365SyncFailed(
          id: '1', entityId: tEntityId)).called(1);
      verifyNever(() => memberRepository.markO365SyncFailed(
          id: '2', entityId: any(named: 'entityId')));
    });

    test('propagates a whole-session failure instead of swallowing it',
        () async {
      // Arrange
      final m1 = member('1');
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findPendingO365Sync(
          entityId: tEntityId,
          limit: any(named: 'limit'))).thenAnswer((_) async => [m1]);
      when(() => syncService.upsertContacts(
              settings: tSettings, members: [m1]))
          .thenThrow(const O365ContactSyncException('could not connect'));

      // Act / Assert
      expect(
        () => sut.execute(entityId: tEntityId),
        throwsA(isA<O365ContactSyncException>()),
      );
    });
  });
}
