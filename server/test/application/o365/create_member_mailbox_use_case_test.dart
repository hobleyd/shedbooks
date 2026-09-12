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

import 'dart:math';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/o365/create_member_mailbox_use_case.dart';
import 'package:shedbooks_server/domain/entities/member.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/member_exception.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_member_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_o365_sync_settings_repository.dart';
import 'package:shedbooks_server/domain/services/i_o365_mailbox_service.dart';
import 'package:shedbooks_server/infrastructure/security/temporary_password_generator.dart';

class MockO365SyncSettingsRepository extends Mock
    implements IO365SyncSettingsRepository {}

class MockMemberRepository extends Mock implements IMemberRepository {}

class MockO365MailboxService extends Mock implements IO365MailboxService {}

void main() {
  late MockO365SyncSettingsRepository settingsRepository;
  late MockMemberRepository memberRepository;
  late MockO365MailboxService mailboxService;
  late CreateMemberMailboxUseCase sut;

  const tEntityId = 'entity-1';
  const tMemberId = 'member-1';
  const tSkuId = 'sku-1';

  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'club.onmicrosoft.com',
    clientId: 'client-guid',
    certificatePfxBase64: 'ZmFrZS1wZng=',
    certificatePassword: 'secret',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  Member member({String? o365MailboxUpn}) => Member(
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
    settingsRepository = MockO365SyncSettingsRepository();
    memberRepository = MockMemberRepository();
    mailboxService = MockO365MailboxService();
    sut = CreateMemberMailboxUseCase(
      settingsRepository,
      memberRepository,
      mailboxService,
      // Seeded so tests are deterministic without mocking a pure utility.
      TemporaryPasswordGenerator(Random(42)),
    );
    when(() => memberRepository.markO365MailboxCreated(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          upn: any(named: 'upn'),
        )).thenAnswer((_) async {});
  });

  group('CreateMemberMailboxUseCase', () {
    test('throws O365SyncNotConfiguredException when settings are missing',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId, entityId: tEntityId, licenseSkuId: tSkuId),
        throwsA(isA<O365SyncNotConfiguredException>()),
      );
    });

    test('throws MemberNotFoundException when the member does not exist',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId, entityId: tEntityId, licenseSkuId: tSkuId),
        throwsA(isA<MemberNotFoundException>()),
      );
    });

    test('throws O365MailboxConflictException when the member already has a mailbox',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member(o365MailboxUpn: 'jane.smith@club.com'));

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId, entityId: tEntityId, licenseSkuId: tSkuId),
        throwsA(isA<O365MailboxConflictException>()),
      );
      verifyNever(() => mailboxService.createMailbox(
            settings: any(named: 'settings'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            localPart: any(named: 'localPart'),
            temporaryPassword: any(named: 'temporaryPassword'),
            licenseSkuId: any(named: 'licenseSkuId'),
          ));
    });

    test('creates the mailbox with a normalized local part and persists the UPN',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());
      when(() => mailboxService.createMailbox(
            settings: tSettings,
            firstName: 'Jane',
            lastName: 'Smith',
            localPart: 'jane.smith',
            temporaryPassword: any(named: 'temporaryPassword'),
            licenseSkuId: tSkuId,
          )).thenAnswer((_) async => const O365MailboxCreateResult(
            upn: 'jane.smith@club.onmicrosoft.com',
            licenseAssigned: true,
          ));

      // Act
      final result = await sut.execute(
          memberId: tMemberId, entityId: tEntityId, licenseSkuId: tSkuId);

      // Assert
      expect(result.upn, 'jane.smith@club.onmicrosoft.com');
      expect(result.licenseAssigned, isTrue);
      expect(result.licenseWarning, isNull);
      expect(result.temporaryPassword, isNotEmpty);
      expect(result.temporaryPassword.length, 16);
      verify(() => memberRepository.markO365MailboxCreated(
            id: tMemberId,
            entityId: tEntityId,
            upn: 'jane.smith@club.onmicrosoft.com',
          )).called(1);
    });

    test('still persists the mailbox and surfaces a warning when licensing fails',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());
      when(() => mailboxService.createMailbox(
            settings: any(named: 'settings'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            localPart: any(named: 'localPart'),
            temporaryPassword: any(named: 'temporaryPassword'),
            licenseSkuId: any(named: 'licenseSkuId'),
          )).thenAnswer((_) async => const O365MailboxCreateResult(
            upn: 'jane.smith@club.onmicrosoft.com',
            licenseAssigned: false,
            licenseError: 'seat taken',
          ));

      // Act
      final result = await sut.execute(
          memberId: tMemberId, entityId: tEntityId, licenseSkuId: tSkuId);

      // Assert
      expect(result.licenseAssigned, isFalse);
      expect(result.licenseWarning, contains('seat taken'));
      verify(() => memberRepository.markO365MailboxCreated(
            id: tMemberId,
            entityId: tEntityId,
            upn: 'jane.smith@club.onmicrosoft.com',
          )).called(1);
    });

    test('propagates O365MailboxConflictException from the mailbox service without persisting',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => memberRepository.findById(tMemberId, entityId: tEntityId))
          .thenAnswer((_) async => member());
      when(() => mailboxService.createMailbox(
            settings: any(named: 'settings'),
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            localPart: any(named: 'localPart'),
            temporaryPassword: any(named: 'temporaryPassword'),
            licenseSkuId: any(named: 'licenseSkuId'),
          )).thenThrow(const O365MailboxConflictException('already exists'));

      // Act / Assert
      expect(
        () => sut.execute(
            memberId: tMemberId, entityId: tEntityId, licenseSkuId: tSkuId),
        throwsA(isA<O365MailboxConflictException>()),
      );
      verifyNever(() => memberRepository.markO365MailboxCreated(
            id: any(named: 'id'),
            entityId: any(named: 'entityId'),
            upn: any(named: 'upn'),
          ));
    });
  });
}
