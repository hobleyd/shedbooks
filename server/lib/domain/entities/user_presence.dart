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

/// Tracks when a user most recently accessed the application.
class UserPresence {
  /// Auth0 organisation ID.
  final String entityId;

  /// Auth0 sub claim (unique user identifier).
  final String userId;

  /// User email from JWT; may be empty for service accounts.
  final String userEmail;

  /// Highest role held by the user at last activity.
  final String role;

  /// UTC timestamp of the user's most recent authenticated request.
  final DateTime lastSeen;

  /// Client IP address at last access.
  final String ipAddress;

  const UserPresence({
    required this.entityId,
    required this.userId,
    required this.userEmail,
    required this.role,
    required this.lastSeen,
    required this.ipAddress,
  });
}
