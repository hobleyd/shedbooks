import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/dashboard_preference.dart';
import 'package:shedbooks_server/domain/repositories/i_dashboard_preference_repository.dart';
import 'package:shedbooks_server/application/dashboard/save_dashboard_preference_use_case.dart';

class MockDashboardPreferenceRepository extends Mock
    implements IDashboardPreferenceRepository {}

void main() {
  late MockDashboardPreferenceRepository repository;
  late SaveDashboardPreferenceUseCase sut;

  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockDashboardPreferenceRepository();
    sut = SaveDashboardPreferenceUseCase(repository);
    registerFallbackValue(
      const DashboardPreference(entityId: tEntityId, selectedAccountPairs: []),
    );
  });

  group('SaveDashboardPreferenceUseCase', () {
    test('persists the selected account pairs for the entity', () async {
      // Arrange
      const pairs = [
        GlAccountPair(incomeGlId: 'income-1', expenseGlId: 'expense-1'),
        GlAccountPair(incomeGlId: 'income-2', expenseGlId: 'expense-2'),
      ];
      when(() => repository.save(any())).thenAnswer((_) async {});

      // Act
      await sut.execute(tEntityId, pairs);

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as DashboardPreference;
      expect(captured.entityId, equals(tEntityId));
      expect(captured.selectedAccountPairs.length, equals(2));
      expect(captured.selectedAccountPairs[0].incomeGlId, equals('income-1'));
      expect(captured.selectedAccountPairs[0].expenseGlId, equals('expense-1'));
    });

    test('persists an empty list when all pairs are removed', () async {
      // Arrange
      when(() => repository.save(any())).thenAnswer((_) async {});

      // Act
      await sut.execute(tEntityId, const []);

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as DashboardPreference;
      expect(captured.selectedAccountPairs, isEmpty);
    });
  });
}
