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

import '../../domain/entities/invoice.dart';
import '../../domain/repositories/i_invoice_repository.dart';

/// Updates an unpaid invoice's number, date, and line items.
///
/// Throws if the invoice is not found within the entity or is already paid.
class UpdateInvoiceUseCase {
  final IInvoiceRepository _repository;

  const UpdateInvoiceUseCase(this._repository);

  Future<Invoice> execute({
    required String id,
    required String entityId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<InvoiceLineItemInput> lineItems,
    String? bankAccountId,
  }) =>
      _repository.update(
        id: id,
        entityId: entityId,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        lineItems: lineItems,
        bankAccountId: bankAccountId,
      );
}
