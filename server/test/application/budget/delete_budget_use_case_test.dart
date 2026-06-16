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

import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/delete_budget_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late DeleteBudgetUseCase sut;

  const tEntityId = 'org-1';

  setUp(() {
    repository = MockBudgetRepository();
    sut = DeleteBudgetUseCase(repository);
    when(() => repository.delete(any(), entityId: any(named: 'entityId')))
        .thenAnswer((_) async {});
  });

  group('DeleteBudgetUseCase', () {
    test('delegates to repository with correct year and entityId', () async {
      // Act
      await sut.execute(2025, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(2025, entityId: tEntityId)).called(1);
    });

    test('passes different years through to repository', () async {
      // Act
      await sut.execute(2026, entityId: tEntityId);

      // Assert
      verify(() => repository.delete(2026, entityId: tEntityId)).called(1);
    });
  });
}
