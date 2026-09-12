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

import 'package:shedbooks_server/application/o365/list_available_o365_licenses_use_case.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_o365_sync_settings_repository.dart';
import 'package:shedbooks_server/domain/services/i_o365_mailbox_service.dart';

class MockO365SyncSettingsRepository extends Mock
    implements IO365SyncSettingsRepository {}

class MockO365MailboxService extends Mock implements IO365MailboxService {}

void main() {
  late MockO365SyncSettingsRepository settingsRepository;
  late MockO365MailboxService mailboxService;
  late ListAvailableO365LicensesUseCase sut;

  const tEntityId = 'entity-1';
  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'club.onmicrosoft.com',
    clientId: 'client-guid',
    certificatePfxBase64: 'ZmFrZS1wZng=',
    certificatePassword: 'secret',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(tSettings);
  });

  setUp(() {
    settingsRepository = MockO365SyncSettingsRepository();
    mailboxService = MockO365MailboxService();
    sut = ListAvailableO365LicensesUseCase(settingsRepository, mailboxService);
  });

  group('ListAvailableO365LicensesUseCase', () {
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
    });

    test('returns the licenses reported by the mailbox service', () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      const licenses = [
        O365LicenseOption(
            skuId: 'sku-1', skuPartNumber: 'SPB', availableUnits: 3),
      ];
      when(() => mailboxService.listAvailableLicenses(settings: tSettings))
          .thenAnswer((_) async => licenses);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, licenses);
    });

    test('propagates O365MailboxException from the mailbox service',
        () async {
      // Arrange
      when(() => settingsRepository.find(tEntityId))
          .thenAnswer((_) async => tSettings);
      when(() => mailboxService.listAvailableLicenses(settings: tSettings))
          .thenThrow(const O365MailboxException('connection failed'));

      // Act / Assert
      expect(
        () => sut.execute(entityId: tEntityId),
        throwsA(isA<O365MailboxException>()),
      );
    });
  });
}
