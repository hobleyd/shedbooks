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

import 'package:shedbooks_server/domain/entities/contact.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/application/contact/list_contacts_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

void main() {
  late MockContactRepository repository;
  late ListContactsUseCase sut;

  const tEntityId = 'entity-1';
  final tContacts = [
    Contact(
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Acme Corp',
      contactType: ContactType.company,
      gstRegistered: true,
      abn: '51824753556',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    Contact(
      id: '00000000-0000-0000-0000-000000000002',
      name: 'Jane Smith',
      contactType: ContactType.person,
      gstRegistered: false,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
  ];

  setUp(() {
    repository = MockContactRepository();
    sut = ListContactsUseCase(repository);
  });

  group('ListContactsUseCase', () {
    test('returns all active contacts from repository', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => tContacts);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tContacts));
      verify(() => repository.findAll(entityId: tEntityId)).called(1);
    });

    test('returns empty list when no contacts exist', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
