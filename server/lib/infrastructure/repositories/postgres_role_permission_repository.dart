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

import 'package:postgres/postgres.dart';

import '../../domain/entities/effective_permissions.dart';
import '../../domain/entities/role_permission_matrix.dart';
import '../../domain/enums/app_role.dart';
import '../../domain/enums/permission_action.dart';
import '../../domain/enums/permission_page.dart';
import '../../domain/repositories/i_entity_details_repository.dart';
import '../../domain/repositories/i_role_permission_repository.dart';

/// PostgreSQL implementation of [IRolePermissionRepository].
///
/// [getEffective] results are cached in memory (keyed by entityId + role)
/// since every guarded request resolves permissions; [save] clears the
/// whole cache rather than tracking fine-grained invalidation — a global
/// defaults save can affect every non-overriding entity, so a targeted
/// invalidation would still need to reason about that case anyway.
class PostgresRolePermissionRepository implements IRolePermissionRepository {
  final Pool _pool;
  final IEntityDetailsRepository _entityDetailsRepository;
  final Map<String, EffectivePermissions> _cache = {};

  PostgresRolePermissionRepository(this._pool, this._entityDetailsRepository);

  @override
  Future<EffectivePermissions> getEffective({
    required String entityId,
    required AppRole role,
  }) async {
    final cacheKey = '$entityId|${role.name}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final isTemplate = await _entityDetailsRepository.isTemplateEntity(entityId);

    final globalPages = await _pageRows(
      'SELECT page_key, can_read, can_write FROM role_page_permission_defaults WHERE role = @role',
      {'role': role.name},
    );
    final overridePages = isTemplate
        ? const <String, ({bool canRead, bool canWrite})>{}
        : await _pageRows(
            'SELECT page_key, can_read, can_write FROM entity_page_permission_overrides '
            'WHERE entity_id = @entityId AND role = @role',
            {'entityId': entityId, 'role': role.name},
          );

    final globalActions = await _actionRows(
      'SELECT action_key, can_perform FROM role_action_permission_defaults WHERE role = @role',
      {'role': role.name},
    );
    final overrideActions = isTemplate
        ? const <String, bool>{}
        : await _actionRows(
            'SELECT action_key, can_perform FROM entity_action_permission_overrides '
            'WHERE entity_id = @entityId AND role = @role',
            {'entityId': entityId, 'role': role.name},
          );

    final pages = <PermissionPage, ({bool canRead, bool canWrite})>{
      for (final page in PermissionPage.values)
        page: overridePages[page.key] ??
            globalPages[page.key] ??
            (canRead: false, canWrite: false),
    };
    final actions = <PermissionAction, bool>{
      for (final action in PermissionAction.values)
        if (overrideActions.containsKey(action.key))
          action: overrideActions[action.key]!
        else if (globalActions.containsKey(action.key))
          action: globalActions[action.key]!,
    };

    final resolved = EffectivePermissions(pages: pages, actions: actions);
    _cache[cacheKey] = resolved;
    return resolved;
  }

  @override
  Future<RolePermissionMatrix> getMatrix(String entityId) async {
    final isTemplate = await _entityDetailsRepository.isTemplateEntity(entityId);

    final globalPages = await _pageRowsByRole(
      'SELECT page_key, role, can_read, can_write FROM role_page_permission_defaults',
      {},
    );
    final overridePages = isTemplate
        ? const <String, Map<String, ({bool canRead, bool canWrite})>>{}
        : await _pageRowsByRole(
            'SELECT page_key, role, can_read, can_write FROM entity_page_permission_overrides '
            'WHERE entity_id = @entityId',
            {'entityId': entityId},
          );

    final globalActions = await _actionRowsByRole(
      'SELECT action_key, role, can_perform FROM role_action_permission_defaults',
      {},
    );
    final overrideActions = isTemplate
        ? const <String, Map<String, bool>>{}
        : await _actionRowsByRole(
            'SELECT action_key, role, can_perform FROM entity_action_permission_overrides '
            'WHERE entity_id = @entityId',
            {'entityId': entityId},
          );

    // For the template entity there is no separate "override" concept — its
    // Roles page edits the global defaults directly, so every seeded global
    // row is, by definition, this entity's own explicit setting.
    final pageOverrideSource = isTemplate ? globalPages : overridePages;
    final actionOverrideSource = isTemplate ? globalActions : overrideActions;

    final pages = <PagePermissionCell>[
      for (final page in PermissionPage.values)
        for (final role in AppRole.values)
          PagePermissionCell(
            page: page,
            role: role,
            canRead: pageOverrideSource[page.key]?[role.name]?.canRead ??
                globalPages[page.key]?[role.name]?.canRead ??
                false,
            canWrite: pageOverrideSource[page.key]?[role.name]?.canWrite ??
                globalPages[page.key]?[role.name]?.canWrite ??
                false,
            isOverride: pageOverrideSource[page.key]?[role.name] != null,
          ),
    ];

    final actions = <ActionPermissionCell>[
      for (final action in PermissionAction.values)
        for (final role in AppRole.values)
          ActionPermissionCell(
            action: action,
            role: role,
            canPerform: actionOverrideSource[action.key]?[role.name] ??
                globalActions[action.key]?[role.name] ??
                pages
                    .firstWhere((c) => c.page == action.page && c.role == role)
                    .canWrite,
            isOverride: actionOverrideSource[action.key]?[role.name] != null,
          ),
    ];

    return RolePermissionMatrix(
      isTemplateEntity: isTemplate,
      pages: pages,
      actions: actions,
    );
  }

  @override
  Future<void> save({
    required String entityId,
    required List<PagePermissionOverride> pages,
    required List<ActionPermissionOverride> actions,
  }) async {
    final isTemplate = await _entityDetailsRepository.isTemplateEntity(entityId);

    await _pool.runTx((tx) async {
      if (isTemplate) {
        await tx.execute('DELETE FROM role_page_permission_defaults');
        await tx.execute('DELETE FROM role_action_permission_defaults');
        for (final p in pages) {
          await tx.execute(
            Sql.named('''
              INSERT INTO role_page_permission_defaults (page_key, role, can_read, can_write)
              VALUES (@pageKey, @role, @canRead, @canWrite)
            '''),
            parameters: {
              'pageKey': p.page.key,
              'role': p.role.name,
              'canRead': p.canRead,
              'canWrite': p.canWrite,
            },
          );
        }
        for (final a in actions) {
          await tx.execute(
            Sql.named('''
              INSERT INTO role_action_permission_defaults (action_key, role, can_perform)
              VALUES (@actionKey, @role, @canPerform)
            '''),
            parameters: {
              'actionKey': a.action.key,
              'role': a.role.name,
              'canPerform': a.canPerform,
            },
          );
        }
      } else {
        await tx.execute(
          Sql.named('DELETE FROM entity_page_permission_overrides WHERE entity_id = @entityId'),
          parameters: {'entityId': entityId},
        );
        await tx.execute(
          Sql.named('DELETE FROM entity_action_permission_overrides WHERE entity_id = @entityId'),
          parameters: {'entityId': entityId},
        );
        for (final p in pages) {
          await tx.execute(
            Sql.named('''
              INSERT INTO entity_page_permission_overrides (entity_id, page_key, role, can_read, can_write)
              VALUES (@entityId, @pageKey, @role, @canRead, @canWrite)
            '''),
            parameters: {
              'entityId': entityId,
              'pageKey': p.page.key,
              'role': p.role.name,
              'canRead': p.canRead,
              'canWrite': p.canWrite,
            },
          );
        }
        for (final a in actions) {
          await tx.execute(
            Sql.named('''
              INSERT INTO entity_action_permission_overrides (entity_id, action_key, role, can_perform)
              VALUES (@entityId, @actionKey, @role, @canPerform)
            '''),
            parameters: {
              'entityId': entityId,
              'actionKey': a.action.key,
              'role': a.role.name,
              'canPerform': a.canPerform,
            },
          );
        }
      }
    });

    _cache.clear();
  }

  Future<Map<String, ({bool canRead, bool canWrite})>> _pageRows(
    String sql,
    Map<String, dynamic> parameters,
  ) async {
    final result = await _pool.execute(Sql.named(sql), parameters: parameters);
    return {
      for (final row in result.map((r) => r.toColumnMap()))
        row['page_key'] as String: (
          canRead: row['can_read'] as bool,
          canWrite: row['can_write'] as bool,
        ),
    };
  }

  Future<Map<String, bool>> _actionRows(
    String sql,
    Map<String, dynamic> parameters,
  ) async {
    final result = await _pool.execute(Sql.named(sql), parameters: parameters);
    return {
      for (final row in result.map((r) => r.toColumnMap()))
        row['action_key'] as String: row['can_perform'] as bool,
    };
  }

  Future<Map<String, Map<String, ({bool canRead, bool canWrite})>>> _pageRowsByRole(
    String sql,
    Map<String, dynamic> parameters,
  ) async {
    final result = await _pool.execute(Sql.named(sql), parameters: parameters);
    final byPage = <String, Map<String, ({bool canRead, bool canWrite})>>{};
    for (final row in result.map((r) => r.toColumnMap())) {
      final pageKey = row['page_key'] as String;
      (byPage[pageKey] ??= {})[row['role'] as String] = (
        canRead: row['can_read'] as bool,
        canWrite: row['can_write'] as bool,
      );
    }
    return byPage;
  }

  Future<Map<String, Map<String, bool>>> _actionRowsByRole(
    String sql,
    Map<String, dynamic> parameters,
  ) async {
    final result = await _pool.execute(Sql.named(sql), parameters: parameters);
    final byAction = <String, Map<String, bool>>{};
    for (final row in result.map((r) => r.toColumnMap())) {
      final actionKey = row['action_key'] as String;
      (byAction[actionKey] ??= {})[row['role'] as String] = row['can_perform'] as bool;
    }
    return byAction;
  }
}
