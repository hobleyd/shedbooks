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

import 'package:shedbooks_server/application/o365/get_o365_sync_settings_use_case.dart';
import 'package:shedbooks_server/domain/entities/o365_sync_settings.dart';
import 'package:shedbooks_server/domain/repositories/i_o365_sync_settings_repository.dart';

class MockO365SyncSettingsRepository extends Mock
    implements IO365SyncSettingsRepository {}

void main() {
  late MockO365SyncSettingsRepository repository;
  late GetO365SyncSettingsUseCase sut;

  const tEntityId = 'entity-1';
  final tSettings = O365SyncSettings(
    entityId: tEntityId,
    tenantId: 'tenant-guid',
    clientId: 'client-guid',
    certificatePfxBase64: 'ZmFrZS1wZng=',
    certificatePassword: 'super-secret',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockO365SyncSettingsRepository();
    sut = GetO365SyncSettingsUseCase(repository);
  });

  group('GetO365SyncSettingsUseCase', () {
    test('returns settings when they exist', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => tSettings);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, equals(tSettings));
    });

    test('returns null when not yet configured', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, isNull);
    });
  });
}
