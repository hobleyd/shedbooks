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

import '../entities/o365_sync_settings.dart';

/// Contract for O365 sync settings persistence.
abstract interface class IO365SyncSettingsRepository {
  /// Returns the settings for [entityId], or null if not yet configured.
  Future<O365SyncSettings?> find(String entityId);

  /// Creates or updates the settings for [settings.entityId].
  ///
  /// [settings.initialSyncCompletedAt] is written as provided — callers
  /// that only want to edit credentials must pass through the existing
  /// value (see [markInitialSyncCompleted] for flipping it on).
  Future<O365SyncSettings> save(O365SyncSettings settings);

  /// Marks the entity as having completed its first manual sync run, if
  /// not already marked. No-ops if no settings row exists.
  Future<void> markInitialSyncCompleted(String entityId);
}
