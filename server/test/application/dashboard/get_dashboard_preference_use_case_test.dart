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

import 'package:shedbooks_server/domain/entities/dashboard_preference.dart';
import 'package:shedbooks_server/domain/repositories/i_dashboard_preference_repository.dart';
import 'package:shedbooks_server/application/dashboard/get_dashboard_preference_use_case.dart';

class MockDashboardPreferenceRepository extends Mock
    implements IDashboardPreferenceRepository {}

void main() {
  late MockDashboardPreferenceRepository repository;
  late GetDashboardPreferenceUseCase sut;

  const tEntityId = 'entity-1';
  const tPairs = [
    GlAccountPair(incomeGlId: 'income-1', expenseGlId: 'expense-1'),
  ];

  setUp(() {
    repository = MockDashboardPreferenceRepository();
    sut = GetDashboardPreferenceUseCase(repository);
  });

  group('GetDashboardPreferenceUseCase', () {
    test('returns existing preference when one has been saved', () async {
      // Arrange
      const stored = DashboardPreference(
        entityId: tEntityId,
        selectedAccountPairs: tPairs,
      );
      when(() => repository.find(tEntityId)).thenAnswer((_) async => stored);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.entityId, equals(tEntityId));
      expect(result.selectedAccountPairs.length, equals(1));
      expect(result.selectedAccountPairs[0].incomeGlId, equals('income-1'));
    });

    test('returns empty preference when none has been saved', () async {
      // Arrange
      when(() => repository.find(tEntityId)).thenAnswer((_) async => null);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result.entityId, equals(tEntityId));
      expect(result.selectedAccountPairs, isEmpty);
    });
  });
}
