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
import 'package:shedbooks_server/application/transaction/stamp_aba_batch_use_case.dart';

class MockTransactionRepository extends Mock implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late StampAbaBatchUseCase sut;

  const tEntityId = 'entity-1';
  const tBatchName = 'WMS260620001';
  const tIds = [
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
  ];

  setUp(() {
    repository = MockTransactionRepository();
    sut = StampAbaBatchUseCase(repository);
    when(() => repository.stampAbaBatch(any(), any(), entityId: any(named: 'entityId')))
        .thenAnswer((_) async {});
  });

  group('StampAbaBatchUseCase', () {
    test('calls stampAbaBatch on repository with correct ids and batch name', () async {
      await sut.execute(ids: tIds, batchName: tBatchName, entityId: tEntityId);

      verify(() => repository.stampAbaBatch(tIds, tBatchName, entityId: tEntityId)).called(1);
    });

    test('does nothing when ids list is empty', () async {
      await sut.execute(ids: const [], batchName: tBatchName, entityId: tEntityId);

      verifyNever(() => repository.stampAbaBatch(any(), any(), entityId: any(named: 'entityId')));
    });

    test('passes single id correctly', () async {
      const singleId = ['00000000-0000-0000-0000-000000000001'];

      await sut.execute(ids: singleId, batchName: tBatchName, entityId: tEntityId);

      verify(() => repository.stampAbaBatch(singleId, tBatchName, entityId: tEntityId)).called(1);
    });

    test('passes different batch names through unchanged', () async {
      const otherBatch = 'WMS260620002';

      await sut.execute(ids: tIds, batchName: otherBatch, entityId: tEntityId);

      verify(() => repository.stampAbaBatch(tIds, otherBatch, entityId: tEntityId)).called(1);
    });
  });
}
