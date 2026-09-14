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

/// Records or clears when a capex request's purchase was actually carried
/// out.
///
/// Deliberately separate from [UpdateCapexRequestUseCase]: the update path
/// is locked once a request is no longer pending, but execution can only be
/// recorded once a decision exists (and sometimes lags it by months), so
/// this action must remain available regardless of decision status.
class SetCapexRequestExecutedDateUseCase {
  final ICapexRequestRepository _repository;

  const SetCapexRequestExecutedDateUseCase(this._repository);

  /// Sets (or clears, when [executedDate] is null) the executed date on the
  /// capex request with [id].
  ///
  /// Throws [CapexRequestNotFoundException] if the request does not exist
  /// or belongs to a different entity.
  Future<CapexRequest> execute({
    required String id,
    required String entityId,
    DateTime? executedDate,
  }) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw CapexRequestNotFoundException(id);

    return _repository.setExecutedDate(
      id: id,
      entityId: entityId,
      executedDate: executedDate,
    );
  }
}
