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
      monthYear: '2026-04',
      lockedAt: DateTime.utc(2026, 5, 1),
    ),
    LockedMonth(
      id: 'id-2',
      entityId: tEntityId,
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
