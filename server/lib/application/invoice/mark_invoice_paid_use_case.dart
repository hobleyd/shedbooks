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
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/i_invoice_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Marks an invoice as paid by creating bank-matched credit transactions for
/// each line item and setting paid_at on the invoice.
class MarkInvoicePaidUseCase {
  final IInvoiceRepository _invoiceRepository;
  final ITransactionRepository _transactionRepository;

  const MarkInvoicePaidUseCase(this._invoiceRepository, this._transactionRepository);

  /// Loads the invoice, creates one credit transaction per line item
  /// (bank-matched), then marks the invoice as paid.
  Future<Invoice> execute(
    String invoiceId, {
    required String entityId,
    required DateTime transactionDate,
  }) async {
    final invoice = await _invoiceRepository.findById(invoiceId, entityId: entityId);
    if (invoice == null) throw Exception('Invoice not found');
    if (invoice.isPaid) throw Exception('Invoice is already paid');
    if (invoice.lineItems.isEmpty) throw Exception('Invoice has no line items');

    final createdIds = <String>[];
    try {
      for (final item in invoice.lineItems) {
        final tx = await _transactionRepository.create(
          entityId: entityId,
          contactId: invoice.contactId,
          generalLedgerId: item.generalLedgerId,
          amount: item.amountCents,
          gstAmount: item.gstCents,
          transactionType: TransactionType.credit,
          receiptNumber: invoice.invoiceNumber,
          description: item.description.isNotEmpty
              ? item.description
              : invoice.invoiceNumber,
          transactionDate: transactionDate,
        );
        createdIds.add(tx.id);
      }
    } catch (_) {
      rethrow;
    }

    // Mark created transactions as bank-matched.
    await _transactionRepository.bankMatch(createdIds, entityId: entityId);

    return _invoiceRepository.markPaid(invoiceId,
        entityId: entityId, paidAt: DateTime.now().toUtc());
  }
}
