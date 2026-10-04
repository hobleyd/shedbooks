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

import '../../domain/entities/effective_permissions.dart';
import '../../domain/enums/app_role.dart';
import '../../domain/repositories/i_role_permission_repository.dart';

/// Fetches the caller's own flattened permissions, for the `/roles/effective`
/// endpoint the client uses to render navigation and action buttons.
class GetEffectivePermissionsUseCase {
  final IRolePermissionRepository _repository;

  const GetEffectivePermissionsUseCase(this._repository);

  Future<EffectivePermissions> execute({
    required String entityId,
    required AppRole role,
  }) =>
      _repository.getEffective(entityId: entityId, role: role);
}
