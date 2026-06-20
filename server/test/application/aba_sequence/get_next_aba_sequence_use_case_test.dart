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

import 'package:shedbooks_server/domain/repositories/i_aba_sequence_repository.dart';
import 'package:shedbooks_server/application/aba_sequence/get_next_aba_sequence_use_case.dart';

class MockAbaSequenceRepository extends Mock implements IAbaSequenceRepository {}

void main() {
  late MockAbaSequenceRepository repository;
  late GetNextAbaSequenceUseCase sut;

  const tEntityId = 'entity-1';

  setUp(() {
    repository = MockAbaSequenceRepository();
    sut = GetNextAbaSequenceUseCase(repository);
  });

  group('GetNextAbaSequenceUseCase', () {
    test('returns 1 on the first call of the day', () async {
      when(() => repository.nextSequence(tEntityId)).thenAnswer((_) async => 1);

      final result = await sut.execute(tEntityId);

      expect(result, equals(1));
      verify(() => repository.nextSequence(tEntityId)).called(1);
    });

    test('returns 2 on the second call of the day', () async {
      // Simulate repository returning incrementing values on successive calls.
      var callCount = 0;
      when(() => repository.nextSequence(tEntityId)).thenAnswer((_) async {
        callCount++;
        return callCount;
      });

      final first = await sut.execute(tEntityId);
      final second = await sut.execute(tEntityId);

      expect(first, equals(1));
      expect(second, equals(2));
      verify(() => repository.nextSequence(tEntityId)).called(2);
    });

    test('sequence numbers pad correctly to produce distinct WMS batch names', () async {
      // The client pads sequence with padLeft(3, '0'). Verify the values
      // the use case returns are the raw integers that the client will pad.
      var callCount = 0;
      when(() => repository.nextSequence(tEntityId)).thenAnswer((_) async => ++callCount);

      final results = <int>[];
      for (int i = 0; i < 3; i++) {
        results.add(await sut.execute(tEntityId));
      }

      expect(results, equals([1, 2, 3]));
      // Confirm client-side padding produces the expected WMS suffixes.
      expect(results.map((n) => n.toString().padLeft(3, '0')).toList(),
          equals(['001', '002', '003']));
    });

    test('different entities maintain independent sequences', () async {
      const otherEntityId = 'entity-2';
      when(() => repository.nextSequence(tEntityId)).thenAnswer((_) async => 2);
      when(() => repository.nextSequence(otherEntityId)).thenAnswer((_) async => 1);

      final entity1Seq = await sut.execute(tEntityId);
      final entity2Seq = await sut.execute(otherEntityId);

      // entity-1 is on its second upload today; entity-2 is on its first.
      expect(entity1Seq, equals(2));
      expect(entity2Seq, equals(1));
    });
  });
}
