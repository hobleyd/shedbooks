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
import 'package:shedbooks_server/domain/repositories/i_general_ledger_repository.dart';
import 'package:shedbooks_server/application/general_ledger/list_general_ledgers_use_case.dart';

class MockGeneralLedgerRepository extends Mock
    implements IGeneralLedgerRepository {}

void main() {
  late MockGeneralLedgerRepository repository;
  late ListGeneralLedgersUseCase sut;

  const tEntityId = 'entity-1';
  final tAccounts = [
    GeneralLedger(
      id: '00000000-0000-0000-0000-000000000001',
      label: 'Cash',
      description: 'Cash on hand',
      gstApplicable: false,
      direction: GlDirection.moneyIn,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
    GeneralLedger(
      id: '00000000-0000-0000-0000-000000000002',
      label: 'Sales Revenue',
      description: 'Revenue from sales',
      gstApplicable: true,
      direction: GlDirection.moneyIn,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    ),
  ];

  setUp(() {
    repository = MockGeneralLedgerRepository();
    sut = ListGeneralLedgersUseCase(repository);
  });

  group('ListGeneralLedgersUseCase', () {
    test('returns all active accounts from repository', () async {
      // Arrange
      when(() => repository.findAll(entityId: tEntityId))
          .thenAnswer((_) async => tAccounts);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tAccounts));
      verify(() => repository.findAll(entityId: tEntityId)).called(1);
    });

    test('returns empty list when no accounts exist', () async {
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
