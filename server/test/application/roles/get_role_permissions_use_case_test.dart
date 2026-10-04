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

import 'package:shedbooks_server/application/roles/get_role_permissions_use_case.dart';
import 'package:shedbooks_server/domain/entities/role_permission_matrix.dart';
import 'package:shedbooks_server/domain/repositories/i_role_permission_repository.dart';

class MockRolePermissionRepository extends Mock
    implements IRolePermissionRepository {}

void main() {
  late MockRolePermissionRepository repository;
  late GetRolePermissionsUseCase sut;

  const tEntityId = 'entity-1';
  const tMatrix = RolePermissionMatrix(
    isTemplateEntity: false,
    pages: [],
    actions: [],
  );

  setUp(() {
    repository = MockRolePermissionRepository();
    sut = GetRolePermissionsUseCase(repository);
  });

  group('GetRolePermissionsUseCase', () {
    test('returns the matrix from the repository', () async {
      // Arrange
      when(() => repository.getMatrix(tEntityId)).thenAnswer((_) async => tMatrix);

      // Act
      final result = await sut.execute(tEntityId);

      // Assert
      expect(result, same(tMatrix));
    });
  });
}
