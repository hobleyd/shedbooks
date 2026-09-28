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

/// Request DTO for `PUT /members/<id>/app-role` and
/// `PUT /admin/users/<userId>/role`.
///
/// [role] is `null` to revoke access entirely, or one of
/// 'viewer'/'contributor'/'administrator'.
class SetAppRoleRequest {
  final String? role;

  const SetAppRoleRequest({this.role});

  static const _validRoles = {'viewer', 'contributor', 'administrator'};

  factory SetAppRoleRequest.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    if (role == null) return const SetAppRoleRequest();
    if (role is! String || !_validRoles.contains(role)) {
      throw FormatException(
          'role must be one of ${_validRoles.join(', ')}, or null');
    }
    return SetAppRoleRequest(role: role);
  }
}
