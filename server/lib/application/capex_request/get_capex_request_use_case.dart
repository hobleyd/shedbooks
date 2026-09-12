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

import '../../domain/entities/capex_request.dart';
import '../../domain/exceptions/capex_request_exception.dart';
import '../../domain/repositories/i_capex_request_repository.dart';

/// Retrieves a single capex request by ID.
class GetCapexRequestUseCase {
  final ICapexRequestRepository _repository;

  const GetCapexRequestUseCase(this._repository);

  /// Returns the [CapexRequest] with [id] scoped to [entityId].
  ///
  /// Throws [CapexRequestNotFoundException] if not found.
  Future<CapexRequest> execute(String id, {required String entityId}) async {
    final request = await _repository.findById(id, entityId: entityId);
    if (request == null) throw CapexRequestNotFoundException(id);
    return request;
  }
}
