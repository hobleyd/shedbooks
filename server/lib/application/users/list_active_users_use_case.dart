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

import '../../domain/entities/user_presence.dart';
import '../../domain/repositories/i_user_presence_repository.dart';

/// Returns all users who have accessed the application for [entityId],
/// ordered by most recently active first.
class ListActiveUsersUseCase {
  final IUserPresenceRepository _repository;

  const ListActiveUsersUseCase(this._repository);

  /// Executes the use case, returning presence records for [entityId].
  Future<List<UserPresence>> execute({required String entityId}) =>
      _repository.findAllByEntity(entityId);
}
