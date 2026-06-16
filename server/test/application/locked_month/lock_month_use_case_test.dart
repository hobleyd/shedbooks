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
import 'package:shedbooks_server/application/locked_month/lock_month_use_case.dart';

class MockLockedMonthRepository extends Mock implements ILockedMonthRepository {}

void main() {
  late MockLockedMonthRepository repository;
  late LockMonthUseCase sut;

  const tEntityId = 'entity-1';
  const tBankAccountId = 'ba-1';

  setUp(() {
    repository = MockLockedMonthRepository();
    sut = LockMonthUseCase(repository);
    when(() => repository.lock(any(), any(), any()))
        .thenAnswer((_) async {});
  });

  group('LockMonthUseCase', () {
    test('calls repository.lock with correct arguments', () async {
      // Act
      await sut.execute(tEntityId, '2026-05', tBankAccountId);

      // Assert
      verify(() => repository.lock(tEntityId, '2026-05', tBankAccountId))
          .called(1);
    });

    test('accepts month 01 through 12', () async {
      for (final m in ['01', '02', '03', '04', '05', '06',
                       '07', '08', '09', '10', '11', '12']) {
        await sut.execute(tEntityId, '2026-$m', tBankAccountId);
        verify(() => repository.lock(tEntityId, '2026-$m', tBankAccountId))
            .called(1);
      }
    });

    test('throws ArgumentError for invalid format', () {
      expect(
        () => sut.execute(tEntityId, '2026-5', tBankAccountId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for month 00', () {
      expect(
        () => sut.execute(tEntityId, '2026-00', tBankAccountId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for month 13', () {
      expect(
        () => sut.execute(tEntityId, '2026-13', tBankAccountId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for bare year', () {
      expect(
        () => sut.execute(tEntityId, '2026', tBankAccountId),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
