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

/// Creates a new invoice with its line items.
class CreateInvoiceUseCase {
  final IInvoiceRepository _repository;

  const CreateInvoiceUseCase(this._repository);

  /// Creates and returns the persisted invoice including its line items.
  Future<Invoice> execute({
    required String entityId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String contactId,
    required List<InvoiceLineItemInput> lineItems,
    String? bankAccountId,
  }) async {
    return _repository.create(
      entityId: entityId,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      contactId: contactId,
      lineItems: lineItems,
      bankAccountId: bankAccountId,
    );
  }
}
