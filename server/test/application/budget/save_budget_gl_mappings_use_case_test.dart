import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/budget_gl_mapping.dart';
import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/save_budget_gl_mappings_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late SaveBudgetGlMappingsUseCase sut;

  const tEntityId = 'org-1';

  setUpAll(() {
    registerFallbackValue(<BudgetGlMapping>[]);
  });

  setUp(() {
    repository = MockBudgetRepository();
    sut = SaveBudgetGlMappingsUseCase(repository);
    when(() => repository.saveMappings(any(), entityId: any(named: 'entityId')))
        .thenAnswer((_) async {});
  });

  group('SaveBudgetGlMappingsUseCase', () {
    test('delegates to repository with correct mappings and entityId', () async {
      // Arrange
      final tMappings = [
        const BudgetGlMapping(
          entityId: tEntityId,
          externalCode: 'MEMB',
          externalName: 'Memberships',
          generalLedgerId: 'gl-1',
        ),
      ];

      // Act
      await sut.execute(tMappings, entityId: tEntityId);

      // Assert
      verify(() => repository.saveMappings(tMappings, entityId: tEntityId)).called(1);
    });

    test('delegates empty list to repository', () async {
      // Act
      await sut.execute([], entityId: tEntityId);

      // Assert
      verify(() => repository.saveMappings([], entityId: tEntityId)).called(1);
    });
  });
}
