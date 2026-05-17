import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/application/locked_month/unlock_month_use_case.dart';

class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockLockedMonthRepository repository;
  late UnlockMonthUseCase sut;

  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockLockedMonthRepository();
    sut = UnlockMonthUseCase(repository);
    when(() => repository.unlock(any(), any())).thenAnswer((_) async {});
  });

  group('UnlockMonthUseCase', () {
    test('calls repository.unlock with correct arguments', () async {
      // Act
      await sut.execute(tEntityId, '2026-04');

      // Assert
      verify(() => repository.unlock(tEntityId, '2026-04')).called(1);
    });

    test('is a no-op when month is not locked (repository handles it)', () async {
      // Act
      await sut.execute(tEntityId, '2026-01');

      // Assert — simply delegates to repository, no exception
      verify(() => repository.unlock(tEntityId, '2026-01')).called(1);
    });
  });
}
