import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/budget_gl_mapping.dart';
import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/get_budget_gl_mappings_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late GetBudgetGlMappingsUseCase sut;

  const tEntityId = 'org-1';

  setUp(() {
    repository = MockBudgetRepository();
    sut = GetBudgetGlMappingsUseCase(repository);
  });

  group('GetBudgetGlMappingsUseCase', () {
    test('returns mappings from repository', () async {
      // Arrange
      final tMappings = [
        const BudgetGlMapping(
          entityId: tEntityId,
          externalCode: 'MEMB',
          externalName: 'Memberships',
          generalLedgerId: 'gl-1',
        ),
        const BudgetGlMapping(
          entityId: tEntityId,
          externalCode: 'RENT',
          externalName: 'Rent',
          generalLedgerId: 'gl-2',
        ),
      ];
      when(() => repository.getMappings(entityId: tEntityId))
          .thenAnswer((_) async => tMappings);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, tMappings);
      verify(() => repository.getMappings(entityId: tEntityId)).called(1);
    });

    test('returns empty list when no mappings exist', () async {
      // Arrange
      when(() => repository.getMappings(entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, isEmpty);
    });
  });
}
