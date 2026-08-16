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

import 'package:shedbooks_server/application/o365/save_o365_sync_settings_use_case.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_o365_sync_settings_repository.dart';

class MockO365SyncSettingsRepository extends Mock
    implements IO365SyncSettingsRepository {}

void main() {
  late MockO365SyncSettingsRepository repository;
  late SaveO365SyncSettingsUseCase sut;

  const tEntityId = 'entity-1';
  final tExisting = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'old-tenant',
    clientId: 'old-client',
    certificatePfxBase64: 'b2xkLXBmeA==',
    certificatePassword: 'old-password',
    initialSyncCompletedAt: DateTime.utc(2026, 3, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockO365SyncSettingsRepository();
    sut = SaveO365SyncSettingsUseCase(repository);
    registerFallbackValue(tExisting);
  });

  group('SaveO365SyncSettingsUseCase', () {
    test('creates settings with a new certificate and password when none exist yet',
        () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: 'bmV3LXBmeA==',
        certificatePassword: 'new-password',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.certificatePfxBase64, equals('bmV3LXBmeA=='));
      expect(captured.certificatePassword, equals('new-password'));
      expect(captured.initialSyncCompletedAt, isNull);
    });

    test('reuses the existing certificate when a blank one is submitted',
        () async {
      // Arrange
      when(() => repository.find(tEntityId))
          .thenAnswer((_) async => tExisting);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: '',
        certificatePassword: 'new-password',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.certificatePfxBase64, equals('b2xkLXBmeA=='));
      expect(captured.certificatePassword, equals('new-password'));
    });

    test('reuses the existing password when a blank one is submitted',
        () async {
      // Arrange
      when(() => repository.find(tEntityId))
          .thenAnswer((_) async => tExisting);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: 'bmV3LXBmeA==',
        certificatePassword: '',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.certificatePfxBase64, equals('bmV3LXBmeA=='));
      expect(captured.certificatePassword, equals('old-password'));
    });

    test('preserves initialSyncCompletedAt from the existing row', () async {
      // Arrange
      when(() => repository.find(tEntityId))
          .thenAnswer((_) async => tExisting);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: 'bmV3LXBmeA==',
        certificatePassword: 'new-password',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.initialSyncCompletedAt,
          equals(tExisting.initialSyncCompletedAt));
    });

    test('throws when creating for the first time without a certificate',
        () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          tenantId: 'tenant-guid',
          clientId: 'client-guid',
          certificatePfxBase64: '',
          certificatePassword: 'new-password',
        ),
        throwsA(isA<O365SyncValidationException>()),
      );
    });

    test('throws when creating for the first time without a password',
        () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          tenantId: 'tenant-guid',
          clientId: 'client-guid',
          certificatePfxBase64: 'bmV3LXBmeA==',
          certificatePassword: '',
        ),
        throwsA(isA<O365SyncValidationException>()),
      );
    });

    test('sets certificateExpiresAt when a new certificate is submitted with one',
        () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);
      final expiry = DateTime.utc(2028, 6, 1);

      // Act
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: 'bmV3LXBmeA==',
        certificatePassword: 'new-password',
        certificateExpiresAt: expiry,
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.certificateExpiresAt, equals(expiry));
    });

    test('clears certificateExpiresAt when a new certificate is submitted without one (manual upload)',
        () async {
      // Arrange
      final existingWithExpiry = O365SyncSettings(
        entityId: tEntityId,
        tenantId: 'old-tenant',
        clientId: 'old-client',
        certificatePfxBase64: 'b2xkLXBmeA==',
        certificatePassword: 'old-password',
        certificateExpiresAt: DateTime.utc(2027, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      when(() => repository.find(tEntityId))
          .thenAnswer((_) async => existingWithExpiry);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act — new pfx (a manually uploaded one), no expiry passed.
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: 'bmV3LXBmeA==',
        certificatePassword: 'new-password',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.certificateExpiresAt, isNull);
    });

    test('preserves certificateExpiresAt when the certificate is unchanged',
        () async {
      // Arrange
      final existingWithExpiry = O365SyncSettings(
        entityId: tEntityId,
        tenantId: 'old-tenant',
        clientId: 'old-client',
        certificatePfxBase64: 'b2xkLXBmeA==',
        certificatePassword: 'old-password',
        certificateExpiresAt: DateTime.utc(2027, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      when(() => repository.find(tEntityId))
          .thenAnswer((_) async => existingWithExpiry);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act — pfx left blank, so the existing certificate (and its expiry)
      // is reused.
      await sut.execute(
        entityId: tEntityId,
        tenantId: 'tenant-guid',
        clientId: 'client-guid',
        certificatePfxBase64: '',
        certificatePassword: 'new-password',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as O365SyncSettings;
      expect(captured.certificateExpiresAt, equals(DateTime.utc(2027, 1, 1)));
    });

    test('throws when tenantId is blank', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          tenantId: '   ',
          clientId: 'client-guid',
          certificatePfxBase64: 'bmV3LXBmeA==',
          certificatePassword: 'new-password',
        ),
        throwsA(isA<O365SyncValidationException>()),
      );
    });

    test('throws when tenantId is a bare GUID instead of a domain', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act / Assert — Exchange Online's certificate-based auth requires
      // the tenant's domain for -Organization and rejects a GUID.
      expect(
        () => sut.execute(
          entityId: tEntityId,
          tenantId: '192514fa-341d-445d-b147-26c45f0af99c',
          clientId: 'client-guid',
          certificatePfxBase64: 'bmV3LXBmeA==',
          certificatePassword: 'new-password',
        ),
        throwsA(isA<O365SyncValidationException>()),
      );
    });

    test('accepts a tenant domain that is not a GUID', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);
      when(() => repository.save(any())).thenAnswer((_) async => tExisting);

      // Act / Assert
      await expectLater(
        sut.execute(
          entityId: tEntityId,
          tenantId: 'yourclub.onmicrosoft.com',
          clientId: 'client-guid',
          certificatePfxBase64: 'bmV3LXBmeA==',
          certificatePassword: 'new-password',
        ),
        completes,
      );
    });

    test('throws when clientId is blank', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          tenantId: 'tenant-guid',
          clientId: '',
          certificatePfxBase64: 'bmV3LXBmeA==',
          certificatePassword: 'new-password',
        ),
        throwsA(isA<O365SyncValidationException>()),
      );
    });
  });
}
