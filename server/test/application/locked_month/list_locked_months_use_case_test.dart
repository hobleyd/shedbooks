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

import 'package:shedbooks_server/domain/entities/locked_month.dart';
import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/application/locked_month/list_locked_months_use_case.dart';

class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockLockedMonthRepository repository;
  late ListLockedMonthsUseCase sut;

  const tEntityId = 'entity-1';
  final tMonths = [
    LockedMonth(
      id: 'id-1',
      entityId: tEntityId,
      bankAccountId: 'ba-1',
      monthYear: '2026-04',
      lockedAt: DateTime.utc(2026, 5, 1),
    ),
    LockedMonth(
      id: 'id-2',
      entityId: tEntityId,
      bankAccountId: 'ba-2',
      monthYear: '2026-03',
      lockedAt: DateTime.utc(2026, 4, 1),
    ),
  ];

  setUp(() {
    repository = MockLockedMonthRepository();
    sut = ListLockedMonthsUseCase(repository);
  });

  group('ListLockedMonthsUseCase', () {
    test('returns all locked months from repository', () async {
      // Arrange
      when(() => repository.findAll(tEntityId)).thenAnswer((_) async => tMonths);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, equals(tMonths));
      verify(() => repository.findAll(tEntityId)).called(1);
    });

    test('returns empty list when no months are locked', () async {
      // Arrange
      when(() => repository.findAll(tEntityId)).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
