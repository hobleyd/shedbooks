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
import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/contact/merge_contacts_use_case.dart';

class MockContactRepository extends Mock implements IContactRepository {}

class MockTransactionRepository extends Mock implements ITransactionRepository {}

Contact _contact(String id, String name) => Contact(
      id: id,
      name: name,
      contactType: ContactType.company,
      gstRegistered: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late MockContactRepository contacts;
  late MockTransactionRepository transactions;
  late MergeContactsUseCase sut;

  const tEntityId = 'entity-1';
  const keepId = '00000000-0000-0000-0000-000000000001';
  const mergeId1 = '00000000-0000-0000-0000-000000000002';
  const mergeId2 = '00000000-0000-0000-0000-000000000003';
  final tKept = _contact(keepId, 'Acme Corp');
  final tMerge1 = _contact(mergeId1, 'Acme Corporation');
  final tMerge2 = _contact(mergeId2, 'ACME');

  setUp(() {
    contacts = MockContactRepository();
    transactions = MockTransactionRepository();
    sut = MergeContactsUseCase(contacts, transactions);
  });

  group('MergeContactsUseCase', () {
    test('returns kept contact and merged names on success', () async {
      // Arrange
      when(() => contacts.findById(keepId, entityId: tEntityId))
          .thenAnswer((_) async => tKept);
      when(() => contacts.findById(mergeId1, entityId: tEntityId))
          .thenAnswer((_) async => tMerge1);
      when(() => contacts.findById(mergeId2, entityId: tEntityId))
          .thenAnswer((_) async => tMerge2);
      when(() => transactions.reassignContact(
            [mergeId1, mergeId2],
            keepId,
            entityId: tEntityId,
          )).thenAnswer((_) async {});
      when(() => contacts.delete(mergeId1, entityId: tEntityId))
          .thenAnswer((_) async {});
      when(() => contacts.delete(mergeId2, entityId: tEntityId))
          .thenAnswer((_) async {});

      // Act
      final result = await sut.execute(
        keepId: keepId,
        mergeIds: [mergeId1, mergeId2],
        entityId: tEntityId,
      );

      // Assert
      expect(result.kept.id, keepId);
      expect(result.mergedNames, ['Acme Corporation', 'ACME']);
    });

    test('reassigns transactions and deletes merged contacts', () async {
      // Arrange
      when(() => contacts.findById(keepId, entityId: tEntityId))
          .thenAnswer((_) async => tKept);
      when(() => contacts.findById(mergeId1, entityId: tEntityId))
          .thenAnswer((_) async => tMerge1);
      when(() => transactions.reassignContact(
            [mergeId1],
            keepId,
            entityId: tEntityId,
          )).thenAnswer((_) async {});
      when(() => contacts.delete(mergeId1, entityId: tEntityId))
          .thenAnswer((_) async {});

      // Act
      await sut.execute(
        keepId: keepId,
        mergeIds: [mergeId1],
        entityId: tEntityId,
      );

      // Assert
      verify(() => transactions.reassignContact(
            [mergeId1],
            keepId,
            entityId: tEntityId,
          )).called(1);
      verify(() => contacts.delete(mergeId1, entityId: tEntityId)).called(1);
    });

    test('throws ContactNotFoundException when keepId contact does not exist',
        () async {
      // Arrange
      when(() => contacts.findById(keepId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
          keepId: keepId,
          mergeIds: [mergeId1],
          entityId: tEntityId,
        ),
        throwsA(isA<ContactNotFoundException>()),
      );
    });

    test('throws ContactNotFoundException when a merge contact does not exist',
        () async {
      // Arrange
      when(() => contacts.findById(keepId, entityId: tEntityId))
          .thenAnswer((_) async => tKept);
      when(() => contacts.findById(mergeId1, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(
          keepId: keepId,
          mergeIds: [mergeId1],
          entityId: tEntityId,
        ),
        throwsA(isA<ContactNotFoundException>()),
      );
      verifyNever(() => transactions.reassignContact(
            any(),
            any(),
            entityId: any(named: 'entityId'),
          ));
    });
  });
}
