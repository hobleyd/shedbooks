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

import 'package:shedbooks_server/application/capex_request/delete_capex_request_use_case.dart';
import 'package:shedbooks_server/domain/repositories/i_capex_request_repository.dart';

class MockCapexRequestRepository extends Mock implements ICapexRequestRepository {}

void main() {
  late MockCapexRequestRepository repository;
  late DeleteCapexRequestUseCase sut;

  const tEntityId = 'entity-1';
  const tId = '00000000-0000-0000-0000-000000000001';

  setUp(() {
    repository = MockCapexRequestRepository();
    sut = DeleteCapexRequestUseCase(repository);
  });

  test('delegates deletion to the repository', () async {
    // Arrange
    when(() => repository.delete(tId, entityId: tEntityId))
        .thenAnswer((_) async {});

    // Act
    await sut.execute(tId, entityId: tEntityId);

    // Assert
    verify(() => repository.delete(tId, entityId: tEntityId)).called(1);
  });
}
