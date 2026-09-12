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

import 'package:shedbooks_server/application/capex_request/get_next_capex_request_no_use_case.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');

  group('GetNextCapexRequestNoUseCase.generateNext', () {
    test('returns 001 when no prior requests exist', () {
      // Act
      final result = GetNextCapexRequestNoUseCase.generateNext([]);

      // Assert
      expect(result, equals('CER $yy-001'));
    });

    test('increments from the highest existing number', () {
      // Act
      final result = GetNextCapexRequestNoUseCase.generateNext(
          ['CER $yy-001', 'CER $yy-011', 'CER $yy-005']);

      // Assert
      expect(result, equals('CER $yy-012'));
    });

    test('ignores numbers from a different year prefix', () {
      // Act
      final result = GetNextCapexRequestNoUseCase.generateNext(
          ['CER $yy-003', 'CER 19-099']);

      // Assert
      expect(result, equals('CER $yy-004'));
    });

    test('handles a gap in numbering by taking the max, not filling the gap',
        () {
      // Act
      final result =
          GetNextCapexRequestNoUseCase.generateNext(['CER $yy-001', 'CER $yy-050']);

      // Assert
      expect(result, equals('CER $yy-051'));
    });
  });

  group('GetNextCapexRequestNoUseCase.execute', () {
    late MockCapexRequestRepository repository;
    late GetNextCapexRequestNoUseCase sut;
    const tEntityId = 'entity-1';

    setUp(() {
      repository = MockCapexRequestRepository();
      sut = GetNextCapexRequestNoUseCase(repository);
    });

    test('queries the repository with the resolved prefix pattern', () async {
      // Arrange
      when(() => repository.findRequestNosLike('CER $yy-%', entityId: tEntityId))
          .thenAnswer((_) async => ['CER $yy-001']);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, equals('CER $yy-002'));
      verify(() =>
              repository.findRequestNosLike('CER $yy-%', entityId: tEntityId))
          .called(1);
    });
  });
}
