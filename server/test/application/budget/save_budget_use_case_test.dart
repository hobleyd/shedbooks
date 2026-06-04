import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/budget_line.dart';
import 'package:shedbooks_server/domain/exceptions/budget_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_budget_repository.dart';
import 'package:shedbooks_server/application/budget/save_budget_use_case.dart';

class MockBudgetRepository extends Mock implements IBudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late SaveBudgetUseCase sut;

  const tEntityId = 'org-1';
  final tLines = [
    const BudgetLine(generalLedgerId: 'gl-1', month: 1, amountCents: 100000),
    const BudgetLine(generalLedgerId: 'gl-1', month: 2, amountCents: 100000),
  ];

  setUp(() {
    repository = MockBudgetRepository();
    sut = SaveBudgetUseCase(repository);
    when(() => repository.saveLines(any(), any(), entityId: any(named: 'entityId')))
        .thenAnswer((_) async {});
  });

  group('SaveBudgetUseCase', () {
    test('delegates to repository with correct args', () async {
      // Act
      await sut.execute(2025, tLines, entityId: tEntityId);

      // Assert
      verify(() => repository.saveLines(2025, tLines, entityId: tEntityId))
          .called(1);
    });

    test('throws BudgetValidationException for year below 1900', () {
      // Assert
      expect(
        () => sut.execute(1899, tLines, entityId: tEntityId),
        throwsA(isA<BudgetValidationException>()),
      );
    });

    test('throws BudgetValidationException for year above 2200', () {
      // Assert
      expect(
        () => sut.execute(2201, tLines, entityId: tEntityId),
        throwsA(isA<BudgetValidationException>()),
      );
    });

    test('accepts boundary years 1900 and 2200', () async {
      // Act & Assert — no exception thrown
      await sut.execute(1900, tLines, entityId: tEntityId);
      await sut.execute(2200, tLines, entityId: tEntityId);
    });
  });
}
