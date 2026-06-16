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

import '../../domain/entities/entity_details.dart';
import '../../domain/exceptions/entity_details_exception.dart';
import '../../domain/repositories/i_entity_details_repository.dart';

/// Retrieves the entity details for an entity.
class GetEntityDetailsUseCase {
  final IEntityDetailsRepository _repository;

  const GetEntityDetailsUseCase(this._repository);

  /// Throws [EntityDetailsNotFoundException] if no details have been saved.
  Future<EntityDetails> execute(String entityId) async {
    final details = await _repository.find(entityId);
    if (details == null) throw EntityDetailsNotFoundException(entityId);
    return details;
  }
}
