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

import '../../domain/entities/member.dart';
import '../../domain/repositories/i_member_repository.dart';

/// Returns all active club members for an entity.
class ListMembersUseCase {
  final IMemberRepository _repository;

  const ListMembersUseCase(this._repository);

  /// Returns all active [Member] records for [entityId], ordered by name.
  Future<List<Member>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
