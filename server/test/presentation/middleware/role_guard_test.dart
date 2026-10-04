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
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/effective_permissions.dart';
import 'package:shedbooks_server/domain/enums/app_role.dart';
import 'package:shedbooks_server/domain/enums/permission_access.dart';
import 'package:shedbooks_server/domain/enums/permission_action.dart';
import 'package:shedbooks_server/domain/enums/permission_page.dart';
import 'package:shedbooks_server/domain/repositories/i_role_permission_repository.dart';
import 'package:shedbooks_server/presentation/middleware/role_guard.dart';

class MockRolePermissionRepository extends Mock
    implements IRolePermissionRepository {}

final _okHandler = (Request req) => Response.ok('ok');

Request _requestAs(AppRole role, {String? entityId = 'entity-1'}) {
  final base = Request('GET', Uri.parse('http://localhost/whatever'));
  return base.change(context: {
    'auth.claims': {
      if (entityId != null) 'https://shedbooks.com/entity_id': entityId,
      'https://shedbooks.com/roles': [role.name],
    },
  });
}

void main() {
  late MockRolePermissionRepository repository;

  setUp(() {
    repository = MockRolePermissionRepository();
  });

  group('requirePagePermission', () {
    test('returns 403 when entity id is missing from claims', () async {
      // Arrange
      final middleware = requirePagePermission(
        repository,
        PermissionPage.adminRoles,
        PermissionAccess.read,
      );

      // Act
      final res = await middleware(_okHandler)(
        _requestAs(AppRole.administrator, entityId: null),
      );

      // Assert
      expect(res.statusCode, equals(403));
    });

    test('returns 403 when the resolved permission denies the requested access', () async {
      // Arrange
      when(() => repository.getEffective(entityId: 'entity-1', role: AppRole.viewer))
          .thenAnswer((_) async => const EffectivePermissions(
                pages: {PermissionPage.adminRoles: (canRead: false, canWrite: false)},
                actions: {},
              ));
      final middleware = requirePagePermission(
        repository,
        PermissionPage.adminRoles,
        PermissionAccess.read,
      );

      // Act
      final res = await middleware(_okHandler)(_requestAs(AppRole.viewer));

      // Assert
      expect(res.statusCode, equals(403));
    });

    test('calls through when the resolved permission grants the requested access', () async {
      // Arrange
      when(() => repository.getEffective(entityId: 'entity-1', role: AppRole.administrator))
          .thenAnswer((_) async => const EffectivePermissions(
                pages: {PermissionPage.adminRoles: (canRead: true, canWrite: true)},
                actions: {},
              ));
      final middleware = requirePagePermission(
        repository,
        PermissionPage.adminRoles,
        PermissionAccess.write,
      );

      // Act
      final res = await middleware(_okHandler)(_requestAs(AppRole.administrator));

      // Assert
      expect(res.statusCode, equals(200));
    });
  });

  group('requireActionPermission', () {
    test('falls back to the page write permission when no explicit action entry exists', () async {
      // Arrange
      when(() => repository.getEffective(entityId: 'entity-1', role: AppRole.contributor))
          .thenAnswer((_) async => const EffectivePermissions(
                pages: {PermissionPage.transactions: (canRead: true, canWrite: true)},
                actions: {},
              ));
      final middleware =
          requireActionPermission(repository, PermissionAction.transactionsImport);

      // Act
      final res = await middleware(_okHandler)(_requestAs(AppRole.contributor));

      // Assert — page write is true, but transactionsImport has no explicit
      // entry here, so canPerform falls back to it in this stub; a real
      // resolver would populate the explicit override instead.
      expect(res.statusCode, equals(200));
    });

    test('returns 403 when an explicit action entry denies access', () async {
      // Arrange
      when(() => repository.getEffective(entityId: 'entity-1', role: AppRole.contributor))
          .thenAnswer((_) async => const EffectivePermissions(
                pages: {PermissionPage.transactions: (canRead: true, canWrite: true)},
                actions: {PermissionAction.transactionsImport: false},
              ));
      final middleware =
          requireActionPermission(repository, PermissionAction.transactionsImport);

      // Act
      final res = await middleware(_okHandler)(_requestAs(AppRole.contributor));

      // Assert
      expect(res.statusCode, equals(403));
    });
  });
}
