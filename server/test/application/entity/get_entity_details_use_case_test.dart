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

import 'package:shedbooks_server/domain/entities/entity_details.dart';
import 'package:shedbooks_server/domain/exceptions/entity_details_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_entity_details_repository.dart';
import 'package:shedbooks_server/application/entity/get_entity_details_use_case.dart';

class MockEntityDetailsRepository extends Mock
    implements IEntityDetailsRepository {}

void main() {
  late MockEntityDetailsRepository repository;
  late GetEntityDetailsUseCase sut;

  const tEntityId = 'entity-1';
  final tDetails = EntityDetails(
    entityId: tEntityId,
    name: 'Woodgate Mens Shed',
    abn: '12345678901',
    incorporationIdentifier: 'IA-2024-001',
    moneyInReceiptFormat: '',
    moneyOutReceiptFormat: 'P-#####',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockEntityDetailsRepository();
    sut = GetEntityDetailsUseCase(repository);
  });

  group('GetEntityDetailsUseCase', () {
    test('returns entity details when they exist', () async {
      // Arrange
      when(() => repository.find(tEntityId))
          .thenAnswer((_) async => tDetails);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.name, equals(tDetails.name));
      expect(result.abn, equals(tDetails.abn));
      expect(result.incorporationIdentifier,
          equals(tDetails.incorporationIdentifier));
    });

    test('throws EntityDetailsNotFoundException when no details exist',
        () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tEntityId),
        throwsA(isA<EntityDetailsNotFoundException>()),
      );
    });
  });
}
