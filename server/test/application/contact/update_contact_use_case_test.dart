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
import 'package:shedbooks_server/domain/exceptions/contact_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_contact_repository.dart';
import 'package:shedbooks_server/application/contact/update_contact_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

void main() {
  late MockContactRepository repository;
  late UpdateContactUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  final tUpdated = Contact(
    id: tId,
    name: 'Acme Pty Ltd',
    contactType: ContactType.company,
    gstRegistered: true,
    abn: '51824753556',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 2, 1),
  );

  setUp(() {
    repository = MockContactRepository();
    sut = UpdateContactUseCase(repository);
    registerFallbackValue(ContactType.person);
  });

  group('UpdateContactUseCase', () {
    test('updates and returns the updated entity', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: any(named: 'entityId'),
          name: 'Acme Pty Ltd',
          contactType: ContactType.company,
          gstRegistered: true,
          abn: '51824753556',
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: 'entity-1',
        name: 'Acme Pty Ltd',
        contactType: ContactType.company,
        gstRegistered: true,
        abn: '51824753556',
      );

      // Assert
      expect(result, equals(tUpdated));
    });

    test('throws ContactValidationException when company ABN is missing',
        () async {
      expect(
        () => sut.execute(
          id: tId,
          entityId: 'entity-1',
          name: 'Acme Pty Ltd',
          contactType: ContactType.company,
          gstRegistered: false,
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('throws ContactValidationException when company ABN is not 11 digits',
        () async {
      expect(
        () => sut.execute(
          id: tId,
          entityId: 'entity-1',
          name: 'Acme Pty Ltd',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '123456',
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('throws ContactValidationException when changing person to gstRegistered true',
        () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: 'entity-1',
          name: 'Jane Smith',
          contactType: ContactType.person,
          gstRegistered: true,
        ),
        throwsA(isA<ContactValidationException>()),
      );
      verifyNever(
        () => repository.update(
          id: any(named: 'id'),
          entityId: any(named: 'entityId'),
          name: any(named: 'name'),
          contactType: any(named: 'contactType'),
          gstRegistered: any(named: 'gstRegistered'),
          abn: any(named: 'abn'),
        ),
      );
    });

    test('throws ContactValidationException when name is empty', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: 'entity-1',
          name: '',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '51824753556',
        ),
        throwsA(isA<ContactValidationException>()),
      );
    });

    test('throws ContactNotFoundException propagated from repository', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: any(named: 'entityId'),
          name: any(named: 'name'),
          contactType: any(named: 'contactType'),
          gstRegistered: any(named: 'gstRegistered'),
          abn: any(named: 'abn'),
        ),
      ).thenThrow(ContactNotFoundException(tId));

      // Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: 'entity-1',
          name: 'Valid Name',
          contactType: ContactType.company,
          gstRegistered: false,
          abn: '51824753556',
        ),
        throwsA(isA<ContactNotFoundException>()),
      );
    });
  });
}
