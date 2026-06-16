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

import 'package:shedbooks_server/domain/entities/general_ledger.dart';
import 'package:shedbooks_server/domain/exceptions/general_ledger_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/delete_general_ledger_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late DeleteGeneralLedgerUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tAccount = GeneralLedger(
    id: tId,
    label: 'Wages',
    description: 'Employee wages expense',
    gstApplicable: false,
    direction: GlDirection.moneyOut,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = DeleteGeneralLedgerUseCase(repository);
  });

  group('DeleteGeneralLedgerUseCase', () {
    test('calls repository delete when account exists', () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tAccount);
      when(() => repository.delete(tId, entityId: tEntityId))
          .thenAnswer((_) async {});

      // Act
      await sut.execute(tId, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(tId, entityId: tEntityId)).called(1);
    });

    test('throws GeneralLedgerNotFoundException when account does not exist',
        () async {
      // Arrange
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<GeneralLedgerNotFoundException>()),
      );
      verifyNever(
          () => repository.delete(any(), entityId: any(named: 'entityId')));
    });

    test('propagates GeneralLedgerHasChildrenException from repository',
        () async {
      // Arrange: account exists but repository rejects delete due to children.
      when(() => repository.findById(tId, entityId: tEntityId))
          .thenAnswer((_) async => tAccount);
      when(() => repository.delete(tId, entityId: tEntityId))
          .thenThrow(GeneralLedgerHasChildrenException(tId));

      // Act / Assert
      await expectLater(
        () => sut.execute(tId, entityId: tEntityId),
        throwsA(isA<GeneralLedgerHasChildrenException>()),
      );
    });
  });
}
