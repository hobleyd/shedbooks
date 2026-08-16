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

import '../../domain/entities/o365_sync_settings.dart';
import '../../domain/repositories/i_o365_sync_settings_repository.dart';

/// Retrieves the O365 sync settings for an entity, if configured.
class GetO365SyncSettingsUseCase {
  final IO365SyncSettingsRepository _repository;

  const GetO365SyncSettingsUseCase(this._repository);

  /// Returns null if O365 sync has not been configured for [entityId].
  Future<O365SyncSettings?> execute(String entityId) => _repository.find(entityId);
}
