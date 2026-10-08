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
import '../../domain/repositories/i_invoice_repository.dart';
import 'validate_capex_request_fields.dart';

/// Updates an existing capex request record.
///
/// Only requests still [CapexRequestStatus.pending] may be edited — once a
/// decision has been recorded the request is a historical record of what
/// was approved or rejected.
class UpdateCapexRequestUseCase {
  final ICapexRequestRepository _repository;
  final IInvoiceRepository _invoices;

  const UpdateCapexRequestUseCase(this._repository, this._invoices);

  /// Validates required fields then updates and returns the [CapexRequest].
  ///
  /// A request that has already been approved or rejected can only be
  /// edited when [allowDecided] is true (the caller holds the
  /// `capex-edit-decided` permission); its decision is left untouched.
  ///
  /// Throws [CapexRequestNotFoundException] if the request does not exist
  /// or belongs to a different entity. Throws
  /// [CapexRequestValidationException] if a field is invalid, [invoiceId]
  /// does not name an invoice belonging to [entityId], or the request has
  /// been decided and [allowDecided] is false.
  Future<CapexRequest> execute({
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
    String? invoiceId,
    bool allowDecided = false,
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

    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw CapexRequestNotFoundException(id);
    if (!existing.isPending && !allowDecided) {
      throw CapexRequestValidationException(
          'Capex request ${existing.requestNo} has already been decided and cannot be edited');
    }
    await validateCapexRequestInvoice(_invoices, invoiceId: invoiceId, entityId: entityId);

    return _repository.update(
      id: id,
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
      invoiceId: invoiceId,
    );
  }
}

String? _blankToNull(String? value) =>
    value?.trim().isEmpty == true ? null : value?.trim();
