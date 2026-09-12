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
import '../../domain/repositories/i_capex_request_repository.dart';
import 'validate_capex_request_fields.dart';

/// Creates a new capex request record.
class CreateCapexRequestUseCase {
  final ICapexRequestRepository _repository;

  const CreateCapexRequestUseCase(this._repository);

  /// Validates required fields then persists and returns the new [CapexRequest].
  Future<CapexRequest> execute({
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
  }) async {
    validateCapexRequestFields(
      requestNo: requestNo,
      preparedByName: preparedByName,
      description: description,
      whatIsRequested: whatIsRequested,
      needOrBenefit: needOrBenefit,
      purchaseCostCents: purchaseCostCents,
      ongoingCostsCents: ongoingCostsCents,
      otherCostsCents: otherCostsCents,
      totalAmountCents: totalAmountCents,
      quotesReceivedCount: quotesReceivedCount,
    );
    return _repository.create(
      entityId: entityId,
      requestNo: requestNo.trim(),
      requestDate: requestDate,
      preparedByName: preparedByName.trim(),
      description: description.trim(),
      whatIsRequested: whatIsRequested.trim(),
      needOrBenefit: needOrBenefit.trim(),
      alternativesConsidered: _blankToNull(alternativesConsidered),
      purchaseCostCents: purchaseCostCents,
      ongoingCostsCents: ongoingCostsCents,
      otherCostsCents: otherCostsCents,
      costNotes: _blankToNull(costNotes),
      totalAmountCents: totalAmountCents,
      quotesReceivedCount: quotesReceivedCount,
    );
  }
}

String? _blankToNull(String? value) =>
    value?.trim().isEmpty == true ? null : value?.trim();
