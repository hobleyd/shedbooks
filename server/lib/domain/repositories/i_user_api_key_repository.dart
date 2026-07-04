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

import '../entities/user_api_key.dart';

/// Contract for [UserApiKey] persistence.
abstract interface class IUserApiKeyRepository {
  /// Returns the key whose hash matches [hash], or null if none exists.
  Future<UserApiKey?> findByApiKeyHash(String hash);

  /// Returns the key for the given user within [entityId], or null.
  Future<UserApiKey?> findByUser({
    required String entityId,
    required String userId,
  });

  /// Inserts or replaces the user's API key record.
  ///
  /// If a row already exists for (entity_id, user_id) it is overwritten with
  /// the new hash and timestamp, effectively regenerating the key.
  Future<void> upsert(UserApiKey key);
}
