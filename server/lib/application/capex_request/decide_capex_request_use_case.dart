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
import '../../domain/enums/capex_request_status.dart';
import '../../domain/exceptions/capex_request_exception.dart';
import '../../domain/repositories/i_capex_request_repository.dart';

/// Records an approve/reject decision against a capex request.
///
/// Mirrors the single "Signed / Date" line on the paper form — a decision
/// is recorded once and is not itself editable; a mis-decided request must
/// be corrected by a new request.
class DecideCapexRequestUseCase {
  final ICapexRequestRepository _repository;

  const DecideCapexRequestUseCase(this._repository);

  /// Approves or rejects the capex request with [id].
  ///
  /// Throws [CapexRequestNotFoundException] if the request does not exist
  /// or belongs to a different entity. Throws [CapexRequestValidationException]
  /// if [status] is not a decision state, [decisionByName] is blank, or the
  /// request has already been decided.
  Future<CapexRequest> execute({
    required String id,
    required String entityId,
    required CapexRequestStatus status,
    required String decisionByName,
    String? decisionNotes,
  }) async {
    if (status == CapexRequestStatus.pending) {
      throw const CapexRequestValidationException(
          'Decision status must be approved or rejected');
    }
    if (decisionByName.trim().isEmpty) {
      throw const CapexRequestValidationException(
          'Decision by name must not be empty');
    }

    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw CapexRequestNotFoundException(id);
    if (!existing.isPending) {
      throw CapexRequestValidationException(
          'Capex request ${existing.requestNo} has already been decided');
    }

    return _repository.decide(
      id: id,
      entityId: entityId,
      status: status,
      decisionByName: decisionByName.trim(),
      decisionNotes: decisionNotes?.trim().isEmpty == true ? null : decisionNotes?.trim(),
    );
  }
}
