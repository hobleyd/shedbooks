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

import 'package:shedbooks_server/application/roles/save_role_permissions_use_case.dart';
import 'package:shedbooks_server/domain/enums/app_role.dart';
import 'package:shedbooks_server/domain/enums/permission_action.dart';
import 'package:shedbooks_server/domain/enums/permission_page.dart';
import 'package:shedbooks_server/domain/exceptions/role_permission_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_entity_details_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_role_permission_repository.dart';

class MockRolePermissionRepository extends Mock
    implements IRolePermissionRepository {}

class MockEntityDetailsRepository extends Mock
    implements IEntityDetailsRepository {}

void main() {
  late MockRolePermissionRepository repository;
  late MockEntityDetailsRepository entityDetailsRepository;
  late SaveRolePermissionsUseCase sut;

  const tEntityId = 'entity-1';
  const tActions = <ActionPermissionOverride>[];

  PagePermissionOverride adminRolesEntry({required bool canRead, required bool canWrite}) => (
        page: PermissionPage.adminRoles,
        role: AppRole.administrator,
        canRead: canRead,
        canWrite: canWrite,
      );

  // A template-entity save must cover every page/role and action/role
  // combination (see IncompleteRoleDefaultsException) — these helpers build
  // that full set, with the Roles/administrator cell overridable for the
  // self-lockout tests.
  List<PagePermissionOverride> fullPageCoverage({
    bool adminRolesCanRead = true,
    bool adminRolesCanWrite = true,
  }) =>
      [
        for (final page in PermissionPage.values)
          for (final role in AppRole.values)
            if (page == PermissionPage.adminRoles && role == AppRole.administrator)
              adminRolesEntry(canRead: adminRolesCanRead, canWrite: adminRolesCanWrite)
            else
              (page: page, role: role, canRead: true, canWrite: true),
      ];

  List<ActionPermissionOverride> fullActionCoverage() => [
        for (final action in PermissionAction.values)
          for (final role in AppRole.values)
            (action: action, role: role, canPerform: true),
      ];

  setUp(() {
    repository = MockRolePermissionRepository();
    entityDetailsRepository = MockEntityDetailsRepository();
    sut = SaveRolePermissionsUseCase(repository, entityDetailsRepository);
    when(() => repository.save(
          entityId: any(named: 'entityId'),
          pages: any(named: 'pages'),
          actions: any(named: 'actions'),
        )).thenAnswer((_) async {});
  });

  group('SaveRolePermissionsUseCase — template entity', () {
    setUp(() {
      when(() => entityDetailsRepository.isTemplateEntity(tEntityId))
          .thenAnswer((_) async => true);
    });

    test('saves a fully-covered matrix that grants administrator full access on the Roles page',
        () async {
      // Arrange
      final pages = fullPageCoverage();
      final actions = fullActionCoverage();

      // Act
      await sut.execute(entityId: tEntityId, pages: pages, actions: actions);

      // Assert
      verify(() => repository.save(entityId: tEntityId, pages: pages, actions: actions))
          .called(1);
    });

    test('rejects when the Roles page entry is missing entirely (incomplete, since a template '
        'save must cover every cell)', () async {
      // Arrange
      final pages = fullPageCoverage()
          .where((p) => !(p.page == PermissionPage.adminRoles && p.role == AppRole.administrator))
          .toList();
      final actions = fullActionCoverage();

      // Act / Assert
      await expectLater(
        sut.execute(entityId: tEntityId, pages: pages, actions: actions),
        throwsA(isA<IncompleteRoleDefaultsException>()),
      );
      verifyNever(() => repository.save(
            entityId: any(named: 'entityId'),
            pages: any(named: 'pages'),
            actions: any(named: 'actions'),
          ));
    });

    test('rejects when the Roles page entry denies write', () async {
      // Arrange
      final pages = fullPageCoverage(adminRolesCanWrite: false);
      final actions = fullActionCoverage();

      // Act / Assert
      await expectLater(
        sut.execute(entityId: tEntityId, pages: pages, actions: actions),
        throwsA(isA<RolesSelfLockoutException>()),
      );
    });

    test('rejects an incomplete page list even when the Roles page entry is fine', () async {
      // Arrange — one page/role combination missing.
      final pages = fullPageCoverage().sublist(1);
      final actions = fullActionCoverage();

      // Act / Assert
      await expectLater(
        sut.execute(entityId: tEntityId, pages: pages, actions: actions),
        throwsA(isA<IncompleteRoleDefaultsException>()),
      );
      verifyNever(() => repository.save(
            entityId: any(named: 'entityId'),
            pages: any(named: 'pages'),
            actions: any(named: 'actions'),
          ));
    });

    test('rejects an incomplete action list', () async {
      // Arrange — one action/role combination missing.
      final pages = fullPageCoverage();
      final actions = fullActionCoverage().sublist(1);

      // Act / Assert
      await expectLater(
        sut.execute(entityId: tEntityId, pages: pages, actions: actions),
        throwsA(isA<IncompleteRoleDefaultsException>()),
      );
    });
  });

  group('SaveRolePermissionsUseCase — non-template entity', () {
    setUp(() {
      when(() => entityDetailsRepository.isTemplateEntity(tEntityId))
          .thenAnswer((_) async => false);
    });

    test('saves when the Roles page entry is omitted (falls back to the protected default)', () async {
      // Arrange
      const pages = <PagePermissionOverride>[];

      // Act
      await sut.execute(entityId: tEntityId, pages: pages, actions: tActions);

      // Assert
      verify(() => repository.save(entityId: tEntityId, pages: pages, actions: tActions))
          .called(1);
    });

    test('saves when an explicit override grants full access', () async {
      // Arrange
      final pages = [adminRolesEntry(canRead: true, canWrite: true)];

      // Act
      await sut.execute(entityId: tEntityId, pages: pages, actions: tActions);

      // Assert
      verify(() => repository.save(entityId: tEntityId, pages: pages, actions: tActions))
          .called(1);
    });

    test('rejects an explicit override that denies read', () async {
      // Arrange
      final pages = [adminRolesEntry(canRead: false, canWrite: true)];

      // Act / Assert
      await expectLater(
        sut.execute(entityId: tEntityId, pages: pages, actions: tActions),
        throwsA(isA<RolesSelfLockoutException>()),
      );
    });
  });
}
