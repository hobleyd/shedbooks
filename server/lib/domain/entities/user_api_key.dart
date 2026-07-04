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

/// A per-user API key used to authenticate CardDAV clients.
///
/// The raw key is never persisted; only its SHA-256 hex digest is stored.
class UserApiKey {
  /// Database row UUID.
  final String id;

  /// Auth0 organisation ID.
  final String entityId;

  /// Auth0 sub claim (unique user identifier).
  final String userId;

  /// User email at the time the key was generated.
  final String userEmail;

  /// SHA-256 hex digest of the raw API key.
  final String apiKeyHash;

  /// UTC timestamp when the key was last generated or regenerated.
  final DateTime createdAt;

  const UserApiKey({
    required this.id,
    required this.entityId,
    required this.userId,
    required this.userEmail,
    required this.apiKeyHash,
    required this.createdAt,
  });
}
