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

/// Thrown when granting/changing a Shedbooks app role via Microsoft Graph
/// fails at the session level (couldn't connect, certificate rejected,
/// PowerShell/module unavailable, target user or resource not found).
class GraphAppRoleException implements Exception {
  final String message;
  const GraphAppRoleException(this.message);

  @override
  String toString() => 'GraphAppRoleException: $message';
}

/// Thrown when an administrator attempts to change their own Shedbooks app
/// role — self-service removal/downgrade could lock the only administrator
/// out of the app with no one able to restore access from within it.
class SelfRoleChangeException implements Exception {
  final String message = 'You cannot change your own Shedbooks access from '
      'here — ask another administrator.';

  const SelfRoleChangeException();

  @override
  String toString() => 'SelfRoleChangeException: $message';
}
