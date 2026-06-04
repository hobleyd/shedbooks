import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/list_budget_years_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late ListBudgetYearsUseCase sut;

  const tEntityId = 'org-1';

  setUp(() {
    repository = MockBudgetRepository();
    sut = ListBudgetYearsUseCase(repository);
  });

  group('ListBudgetYearsUseCase', () {
    test('returns years from repository', () async {
      // Arrange
      when(() => repository.listYears(entityId: tEntityId))
          .thenAnswer((_) async => [2024, 2025]);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, [2024, 2025]);
      verify(() => repository.listYears(entityId: tEntityId)).called(1);
    });

    test('returns empty list when no budgets exist', () async {
      // Arrange
      when(() => repository.listYears(entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
