import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/application/locked_month/lock_month_use_case.dart';

class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockLockedMonthRepository repository;
  late LockMonthUseCase sut;

  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockLockedMonthRepository();
    sut = LockMonthUseCase(repository);
    when(() => repository.lock(any(), any())).thenAnswer((_) async {});
  });

  group('LockMonthUseCase', () {
    test('calls repository.lock with correct arguments', () async {
      // Act
      await sut.execute(tEntityId, '2026-05');

      // Assert
      verify(() => repository.lock(tEntityId, '2026-05')).called(1);
    });

    test('accepts month 01 through 12', () async {
      for (final m in ['01', '02', '03', '04', '05', '06',
                       '07', '08', '09', '10', '11', '12']) {
        await sut.execute(tEntityId, '2026-$m');
        verify(() => repository.lock(tEntityId, '2026-$m')).called(1);
      }
    });

    test('throws ArgumentError for invalid format', () {
      expect(
        () => sut.execute(tEntityId, '2026-5'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for month 00', () {
      expect(
        () => sut.execute(tEntityId, '2026-00'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for month 13', () {
      expect(
        () => sut.execute(tEntityId, '2026-13'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for bare year', () {
      expect(
        () => sut.execute(tEntityId, '2026'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
