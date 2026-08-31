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

import 'package:shedbooks_server/application/asset/list_asset_sections_use_case.dart';
import 'package:shedbooks_server/domain/repositories/i_asset_repository.dart';

class MockAssetRepository extends Mock implements IAssetRepository {}

void main() {
  late MockAssetRepository repository;
  late ListAssetSectionsUseCase sut;

  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockAssetRepository();
    sut = ListAssetSectionsUseCase(repository);
  });

  group('ListAssetSectionsUseCase', () {
    test('returns the distinct sections from the repository', () async {
      // Arrange
      when(() => repository.findDistinctSections(entityId: tEntityId))
          .thenAnswer((_) async => ['Metal Shop', 'Nursery', 'Wood Shop']);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(['Metal Shop', 'Nursery', 'Wood Shop']));
    });

    test('returns an empty list when the entity has no assets yet', () async {
      // Arrange
      when(() => repository.findDistinctSections(entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
