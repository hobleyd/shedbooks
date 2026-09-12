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

import '../entities/capex_request.dart';
import '../enums/capex_request_status.dart';

/// Contract for capex request persistence.
abstract interface class ICapexRequestRepository {
  /// Creates a new capex request and returns the persisted entity.
  Future<CapexRequest> create({
    required String entityId,
    required String requestNo,
    required DateTime requestDate,
    required String preparedByName,
    required String description,
    required String whatIsRequested,
    required String needOrBenefit,
    String? alternativesConsidered,
    required int purchaseCostCents,
    int? ongoingCostsCents,
    int? otherCostsCents,
    String? costNotes,
    required int totalAmountCents,
    int? quotesReceivedCount,
  });

  /// Returns the capex request with [id] scoped to [entityId], or null if not found.
  Future<CapexRequest?> findById(String id, {required String entityId});

  /// Returns all active capex requests for [entityId], newest request date first.
  Future<List<CapexRequest>> findAll({required String entityId});

  /// Updates the capex request with [id] and returns the updated entity.
  ///
  /// Throws [CapexRequestNotFoundException] if the request does not exist,
  /// belongs to a different entity, or has already been decided.
  Future<CapexRequest> update({
    required String id,
    required String entityId,
    required String requestNo,
    required DateTime requestDate,
    required String preparedByName,
    required String description,
    required String whatIsRequested,
    required String needOrBenefit,
    String? alternativesConsidered,
    required int purchaseCostCents,
    int? ongoingCostsCents,
    int? otherCostsCents,
    String? costNotes,
    required int totalAmountCents,
    int? quotesReceivedCount,
  });

  /// Records an approve/reject decision on the capex request with [id].
  ///
  /// Throws [CapexRequestNotFoundException] if the request does not exist
  /// or belongs to a different entity.
  Future<CapexRequest> decide({
    required String id,
    required String entityId,
    required CapexRequestStatus status,
    required String decisionByName,
    String? decisionNotes,
  });

  /// Soft-deletes the capex request with [id].
  ///
  /// Throws [CapexRequestNotFoundException] if the request does not exist
  /// or belongs to a different entity.
  Future<void> delete(String id, {required String entityId});

  /// Returns the distinct request numbers for [entityId] whose value matches
  /// [pattern] (a SQL `LIKE` pattern, e.g. `'CER 26-%'`).
  ///
  /// Used to derive the next sequential request number.
  Future<List<String>> findRequestNosLike(String pattern,
      {required String entityId});
}
