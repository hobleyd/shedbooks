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

import 'package:shedbooks_server/application/o365/member_o365_auto_sync.dart';
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
  late MemberO365AutoSync sut;

  const tEntityId = 'entity-1';
  final tMember = Member(
    id: 'member-1',
    entityId: tEntityId,
    firstName: 'Ron',
    lastName: 'Anderson',
    email: 'ron@example.com',
    etag: 'etag-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  O365SyncSettings settingsWith({DateTime? initialSyncCompletedAt}) =>
      O365SyncSettings(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: 'ZmFrZS1wZng=',
        certificatePassword: 'secret',
        initialSyncCompletedAt: initialSyncCompletedAt,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(settingsWith());
    registerFallbackValue(tMember);
  });

  setUp(() {
    settingsRepository = MockO365SyncSettingsRepository();
    memberRepository = MockMemberRepository();
    syncService = MockO365ContactSyncService();
    sut = MemberO365AutoSync(settingsRepository, memberRepository, syncService);
  });

  group('MemberO365AutoSync', () {
    test('does nothing when O365 sync has not been configured', () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => null);

      // Act
      await sut.maybeSync(tEntityId, tMember);

      // Assert
      verifyNever(() => syncService.upsertContacts(
          settings: any(named: 'settings'), members: any(named: 'members')));
    });

    test('does nothing when the entity has not run its first manual sync',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => settingsWith(initialSyncCompletedAt: null));

      // Act
      await sut.maybeSync(tEntityId, tMember);

      // Assert
      verifyNever(() => syncService.upsertContacts(
          settings: any(named: 'settings'), members: any(named: 'members')));
    });

    test('pushes the member as a single-item batch and marks it synced once '
        'auto-sync is enabled', () async {
      // Arrange
      final settings =
          settingsWith(initialSyncCompletedAt: DateTime.utc(2026, 3, 1));
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => settings);
      when(() => syncService.upsertContacts(
              settings: settings, members: [tMember]))
          .thenAnswer((_) async => [
                O365ContactSyncResult(
                    memberId: tMember.id, contactId: 'gal-id-1'),
              ]);
      when(() => memberRepository.markO365Synced(
          id: tMember.id,
          entityId: tEntityId,
          o365ContactId: 'gal-id-1')).thenAnswer((_) async {});

      // Act
      await sut.maybeSync(tEntityId, tMember);

      // Assert
      verify(() => memberRepository.markO365Synced(
          id: tMember.id,
          entityId: tEntityId,
          o365ContactId: 'gal-id-1')).called(1);
    });

    test('swallows a per-member failure instead of throwing', () async {
      // Arrange
      final settings =
          settingsWith(initialSyncCompletedAt: DateTime.utc(2026, 3, 1));
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => settings);
      when(() => syncService.upsertContacts(
              settings: settings, members: [tMember]))
          .thenAnswer((_) async => [
                O365ContactSyncResult(
                  memberId: tMember.id,
                  error: const O365ContactSyncException('graph is down'),
                ),
              ]);

      // Act / Assert — must not throw.
      await sut.maybeSync(tEntityId, tMember);
      verifyNever(() => memberRepository.markO365Synced(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          o365ContactId: any(named: 'o365ContactId')));
    });

    test('swallows a whole-session failure instead of throwing', () async {
      // Arrange
      final settings =
          settingsWith(initialSyncCompletedAt: DateTime.utc(2026, 3, 1));
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => settings);
      when(() => syncService.upsertContacts(
              settings: settings, members: [tMember]))
          .thenThrow(const O365ContactSyncException('could not connect'));

      // Act / Assert — must not throw.
      await sut.maybeSync(tEntityId, tMember);
      verifyNever(() => memberRepository.markO365Synced(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          o365ContactId: any(named: 'o365ContactId')));
    });
  });
}
