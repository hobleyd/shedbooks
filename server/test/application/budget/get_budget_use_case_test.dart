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

import 'package:shedbooks_server/domain/entities/budget_line.dart';
import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/get_budget_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late GetBudgetUseCase sut;

  const tEntityId = 'org-1';

  setUp(() {
    repository = MockBudgetRepository();
    sut = GetBudgetUseCase(repository);
  });

  group('GetBudgetUseCase', () {
    test('returns lines from repository', () async {
      // Arrange
      final tLines = [
        const BudgetLine(generalLedgerId: 'gl-1', month: 1, amountCents: 100000),
        const BudgetLine(generalLedgerId: 'gl-2', month: 3, amountCents: 50000),
      ];
      when(() => repository.getLines(2025, entityId: tEntityId))
          .thenAnswer((_) async => tLines);

      // Act
      final result = await sut.execute(2025, entityId: tEntityId);

      // Assert
      expect(result, tLines);
      verify(() => repository.getLines(2025, entityId: tEntityId)).called(1);
    });

    test('returns empty list when no budget exists', () async {
      // Arrange
      when(() => repository.getLines(2025, entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(2025, entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });

    test('passes correct year to repository', () async {
      // Arrange
      when(() => repository.getLines(2026, entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      await sut.execute(2026, entityId: tEntityId);

      // Assert
      verify(() => repository.getLines(2026, entityId: tEntityId)).called(1);
    });
  });
}
