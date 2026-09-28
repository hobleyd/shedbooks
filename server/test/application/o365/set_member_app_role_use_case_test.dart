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

import 'package:shedbooks_server/application/o365/set_member_app_role_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/app_role_exception.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_o365_sync_settings_repository.dart';
import 'package:shedbooks_server/domain/services/i_graph_app_role_service.dart';

class MockMemberRepository extends Mock implements IMemberRepository {}

class MockO365SyncSettingsRepository extends Mock
    implements IO365SyncSettingsRepository {}

class MockGraphAppRoleService extends Mock implements IGraphAppRoleService {}

void main() {
  late MockMemberRepository memberRepository;
  late MockO365SyncSettingsRepository settingsRepository;
  late MockGraphAppRoleService graphService;
  late SetMemberAppRoleUseCase sut;

  const tEntityId = 'entity-1';
  const tMemberId = 'member-1';
  const tResourceId = 'sp-object-id';
  const tUpn = 'jane.smith@club.onmicrosoft.com';

  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'club.onmicrosoft.com',
    clientId: 'client-guid',
    certificatePfxBase64: 'ZmFrZS1wZng=',
    certificatePassword: 'secret',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Member member({String? o365MailboxUpn = tUpn}) => Member(
        id: tMemberId,
        entityId: tEntityId,
        firstName: 'Jane',
        lastName: 'Smith',
        etag: 'etag-1',
        o365MailboxUpn: o365MailboxUpn,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  setUpAll(() {
    registerFallbackValue(tSettings);
  });

  setUp(() {
    memberRepository = MockMemberRepository();
    settingsRepository = MockO365SyncSettingsRepository();
    graphService = MockGraphAppRoleService();
    sut = SetMemberAppRoleUseCase(
        memberRepository, settingsRepository, graphService, tResourceId);

    when(() => memberRepository.setShedbooksAppRole(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          role: any(named: 'role'),
        )).thenAnswer((_) async {});
  });

  group('SetMemberAppRoleUseCase', () {
    test('throws MemberNotFoundException when the member does not exist',
        () async {
      // Arrange
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId,
            entityId: tEntityId,
            appRole: 'contributor',
            callerEmail: 'admin@club.onmicrosoft.com'),
        throwsA(isA<MemberNotFoundException>()),
      );
    });

    test('throws MemberValidationException when the member has no O365 mailbox',
        () async {
      // Arrange
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member(o365MailboxUpn: null));

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId,
            entityId: tEntityId,
            appRole: 'contributor',
            callerEmail: 'admin@club.onmicrosoft.com'),
        throwsA(isA<MemberValidationException>()),
      );
    });

    test('throws SelfRoleChangeException when the caller targets their own mailbox address',
        () async {
      // Arrange
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId,
            entityId: tEntityId,
            appRole: null,
            callerEmail: 'JANE.SMITH@CLUB.ONMICROSOFT.COM'),
        throwsA(isA<SelfRoleChangeException>()),
      );
      verifyNever(() => graphService.setAppRole(
            settings: any(named: 'settings'),
            resourceServicePrincipalId: any(named: 'resourceServicePrincipalId'),
            targetUserId: any(named: 'targetUserId'),
            appRole: any(named: 'appRole'),
          ));
    });

    test('throws O365SyncNotConfiguredException when settings are missing',
        () async {
      // Arrange
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId,
            entityId: tEntityId,
            appRole: 'contributor',
            callerEmail: 'admin@club.onmicrosoft.com'),
        throwsA(isA<O365SyncNotConfiguredException>()),
      );
    });

    test('grants the role via Graph and persists the resulting role', () async {
      // Arrange
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => graphService.setAppRole(
            settings: tSettings,
            resourceServicePrincipalId: tResourceId,
            targetUserId: tUpn,
            appRole: 'contributor',
          )).thenAnswer((_) async => 'contributor');

      // Act
      final result = await sut.execute(
          memberId: tMemberId,
          entityId: tEntityId,
          appRole: 'contributor',
          callerEmail: 'admin@club.onmicrosoft.com');

      // Assert
      expect(result, 'contributor');
      verify(() => memberRepository.setShedbooksAppRole(
            id: tMemberId,
            entityId: tEntityId,
            role: 'contributor',
          )).called(1);
    });

    test('revokes access when appRole is null and persists null', () async {
      // Arrange
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => graphService.setAppRole(
            settings: tSettings,
            resourceServicePrincipalId: tResourceId,
            targetUserId: tUpn,
            appRole: null,
          )).thenAnswer((_) async => null);

      // Act
      final result = await sut.execute(
          memberId: tMemberId,
          entityId: tEntityId,
          appRole: null,
          callerEmail: 'admin@club.onmicrosoft.com');

      // Assert
      expect(result, isNull);
      verify(() => memberRepository.setShedbooksAppRole(
            id: tMemberId,
            entityId: tEntityId,
            role: null,
          )).called(1);
    });
  });
}
