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

import 'package:shedbooks_server/domain/repositories/i_transaction_repository.dart';
import 'package:shedbooks_server/application/transaction/bank_match_transactions_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late BankMatchTransactionsUseCase sut;

  const tEntityId = 'entity-1';
  const tBankAccountId = '00000000-0000-0000-0000-0000000000aa';
  const tIds = [
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
  ];

  setUp(() {
    repository = MockTransactionRepository();
    sut = BankMatchTransactionsUseCase(repository);
    when(() => repository.bankMatch(
          any(),
          entityId: any(named: 'entityId'),
          bankAccountId: any(named: 'bankAccountId'),
        )).thenAnswer((_) async {});
  });

  group('BankMatchTransactionsUseCase', () {
    test('calls bankMatch on repository with ids, entityId and bankAccountId', () async {
      await sut.execute(
        ids: tIds,
        entityId: tEntityId,
        bankAccountId: tBankAccountId,
      );

      verify(() => repository.bankMatch(
            tIds,
            entityId: tEntityId,
            bankAccountId: tBankAccountId,
          )).called(1);
    });

    test('passes null bankAccountId through unchanged when not provided', () async {
      await sut.execute(ids: tIds, entityId: tEntityId);

      verify(() => repository.bankMatch(
            tIds,
            entityId: tEntityId,
            bankAccountId: null,
          )).called(1);
    });

    test('does nothing when ids list is empty', () async {
      await sut.execute(
        ids: const [],
        entityId: tEntityId,
        bankAccountId: tBankAccountId,
      );

      verifyNever(() => repository.bankMatch(
            any(),
            entityId: any(named: 'entityId'),
            bankAccountId: any(named: 'bankAccountId'),
          ));
    });
  });
}
