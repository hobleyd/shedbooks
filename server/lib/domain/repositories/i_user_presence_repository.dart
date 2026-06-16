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

import '../entities/user_presence.dart';

/// Contract for user presence persistence.
abstract interface class IUserPresenceRepository {
  /// Inserts or updates the user's presence record.
  ///
  /// Updates [UserPresence.userEmail], [UserPresence.role], last_seen, and
  /// [UserPresence.ipAddress] when a row for (entity_id, user_id) already
  /// exists.  Failures are non-fatal — callers should swallow errors.
  Future<void> upsert(UserPresence presence);

  /// Returns all presence records for [entityId], ordered by last_seen
  /// descending (most recently active first).
  Future<List<UserPresence>> findAllByEntity(String entityId);
}
