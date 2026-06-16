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

import 'package:shedbooks_server/domain/repositories/i_locked_month_repository.dart';
import 'package:shedbooks_server/application/locked_month/unlock_month_use_case.dart';

class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockLockedMonthRepository repository;
  late UnlockMonthUseCase sut;

  const tEntityId = 'entity-1';
  const tBankAccountId = 'ba-1';

  setUp(() {
    repository = MockLockedMonthRepository();
    sut = UnlockMonthUseCase(repository);
    when(() => repository.unlock(any(), any(), any()))
        .thenAnswer((_) async {});
  });

  group('UnlockMonthUseCase', () {
    test('calls repository.unlock with correct arguments', () async {
      // Act
      await sut.execute(tEntityId, '2026-04', tBankAccountId);

      // Assert
      verify(() => repository.unlock(tEntityId, '2026-04', tBankAccountId))
          .called(1);
    });

    test('is a no-op when month is not locked (repository handles it)',
        () async {
      // Act
      await sut.execute(tEntityId, '2026-01', tBankAccountId);

      // Assert — simply delegates to repository, no exception
      verify(() => repository.unlock(tEntityId, '2026-01', tBankAccountId))
          .called(1);
    });
  });
}
