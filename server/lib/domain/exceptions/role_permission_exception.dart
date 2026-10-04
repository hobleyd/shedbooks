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

/// Thrown when a Roles-page save would leave the `administrator` role
/// without both read and write on the Roles page itself. There is no other
/// in-app path to restore access once that happens, so the save is rejected
/// outright rather than persisted — the same reasoning as
/// [SelfRoleChangeException] for per-user role assignment.
class RolesSelfLockoutException implements Exception {
  final String message = 'Administrators must always be able to read and '
      'write the Roles page — this change would remove that.';

  const RolesSelfLockoutException();

  @override
  String toString() => 'RolesSelfLockoutException: $message';
}

/// Thrown when the template entity's save omits a page or action row.
///
/// The template entity's save *is* the global defaults table (there's no
/// layer above it to fall back to), so a missing row doesn't "inherit" —
/// it deletes the only definition that cell has, silently widening it for
/// every entity that hasn't overridden it. Full coverage is required rather
/// than trying to diff against what currently exists.
class IncompleteRoleDefaultsException implements Exception {
  final String message = 'The platform template must set every page and '
      'action explicitly — none can be left to "inherit".';

  const IncompleteRoleDefaultsException();

  @override
  String toString() => 'IncompleteRoleDefaultsException: $message';
}
