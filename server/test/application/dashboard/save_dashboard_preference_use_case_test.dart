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
      const DashboardPreference(entityId: tEntityId, selectedGlIds: []),
    );
  });

  group('SaveDashboardPreferenceUseCase', () {
    test('persists the selected GL ids for the entity', () async {
      // Arrange
      const selectedGlIds = ['gl-1', 'gl-2'];
      when(() => repository.save(any())).thenAnswer((_) async {});

      // Act
      await sut.execute(tEntityId, selectedGlIds);

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as DashboardPreference;
      expect(captured.entityId, equals(tEntityId));
      expect(captured.selectedGlIds, equals(selectedGlIds));
    });

    test('persists an empty list when all GL accounts are removed', () async {
      // Arrange
      when(() => repository.save(any())).thenAnswer((_) async {});

      // Act
      await sut.execute(tEntityId, const []);

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as DashboardPreference;
      expect(captured.selectedGlIds, isEmpty);
    });
  });
}
