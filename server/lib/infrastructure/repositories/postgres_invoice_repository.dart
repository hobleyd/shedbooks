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

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/repositories/i_invoice_repository.dart';

/// PostgreSQL implementation of [IInvoiceRepository].
class PostgresInvoiceRepository implements IInvoiceRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresInvoiceRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  @override
  Future<Invoice> create({
    required String entityId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String contactId,
    required List<InvoiceLineItemInput> lineItems,
    String? bankAccountId,
  }) async {
    final totalAmountCents =
        lineItems.fold(0, (sum, i) => sum + i.amountCents);
    final totalGstCents = lineItems.fold(0, (sum, i) => sum + i.gstCents);
    final invoiceId = _uuid.v4();
    final invoiceDateStr =
        invoiceDate.toIso8601String().substring(0, 10);

    return await _pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named('''
          INSERT INTO invoices (
            id, entity_id, invoice_number, invoice_date,
            contact_id, total_amount_cents, total_gst_cents,
            bank_account_id
          )
          VALUES (
            @id::uuid, @entityId, @invoiceNumber, @invoiceDate::date,
            @contactId::uuid, @totalAmountCents, @totalGstCents,
            @bankAccountId::uuid
          )
          RETURNING
            id, entity_id, invoice_number, invoice_date,
            contact_id, total_amount_cents, total_gst_cents,
            bank_account_id, paid_at, created_at, updated_at
        '''),
        parameters: {
          'id': invoiceId,
          'entityId': entityId,
          'invoiceNumber': invoiceNumber,
          'invoiceDate': invoiceDateStr,
          'contactId': contactId,
          'totalAmountCents': totalAmountCents,
          'totalGstCents': totalGstCents,
          'bankAccountId': bankAccountId,
        },
      );

      final invoice = _mapInvoiceRow(rows.first.toColumnMap());

      final createdLineItems = <InvoiceLineItem>[];
      for (final item in lineItems) {
        final itemId = _uuid.v4();
        final itemRows = await tx.execute(
          Sql.named('''
            INSERT INTO invoice_line_items (
              id, entity_id, invoice_id, description,
              general_ledger_id, amount_cents, gst_cents
            )
            VALUES (
              @id::uuid, @entityId, @invoiceId::uuid, @description,
              @generalLedgerId::uuid, @amountCents, @gstCents
            )
            RETURNING
              id, invoice_id, description, general_ledger_id,
              amount_cents, gst_cents, created_at
          '''),
          parameters: {
            'id': itemId,
            'entityId': entityId,
            'invoiceId': invoiceId,
            'description': item.description,
            'generalLedgerId': item.generalLedgerId,
            'amountCents': item.amountCents,
            'gstCents': item.gstCents,
          },
        );
        createdLineItems.add(_mapLineItemRow(itemRows.first.toColumnMap()));
      }

      return Invoice(
        id: invoice.id,
        entityId: invoice.entityId,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.invoiceDate,
        contactId: invoice.contactId,
        totalAmountCents: invoice.totalAmountCents,
        totalGstCents: invoice.totalGstCents,
        bankAccountId: invoice.bankAccountId,
        paidAt: invoice.paidAt,
        createdAt: invoice.createdAt,
        updatedAt: invoice.updatedAt,
        lineItems: createdLineItems,
      );
    });
  }

  @override
  Future<List<Invoice>> findAll({
    required String entityId,
    bool unpaidOnly = false,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT
          id, entity_id, invoice_number, invoice_date,
          contact_id, total_amount_cents, total_gst_cents,
          bank_account_id, paid_at, created_at, updated_at
        FROM invoices
        WHERE entity_id = @entityId
          ${unpaidOnly ? 'AND paid_at IS NULL' : ''}
        ORDER BY invoice_date DESC, created_at DESC
      '''),
      parameters: {'entityId': entityId},
    );

    return result.map((r) => _mapInvoiceRow(r.toColumnMap())).toList();
  }

  @override
  Future<Invoice?> findById(String id, {required String entityId}) async {
    final invoiceRows = await _pool.execute(
      Sql.named('''
        SELECT
          id, entity_id, invoice_number, invoice_date,
          contact_id, total_amount_cents, total_gst_cents,
          bank_account_id, paid_at, created_at, updated_at
        FROM invoices
        WHERE id = @id::uuid
          AND entity_id = @entityId
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (invoiceRows.isEmpty) return null;

    final invoice = _mapInvoiceRow(invoiceRows.first.toColumnMap());

    final itemRows = await _pool.execute(
      Sql.named('''
        SELECT
          id, invoice_id, description, general_ledger_id,
          amount_cents, gst_cents, created_at
        FROM invoice_line_items
        WHERE invoice_id = @invoiceId::uuid
          AND entity_id = @entityId
        ORDER BY created_at ASC
      '''),
      parameters: {'invoiceId': id, 'entityId': entityId},
    );

    final lineItems =
        itemRows.map((r) => _mapLineItemRow(r.toColumnMap())).toList();

    return Invoice(
      id: invoice.id,
      entityId: invoice.entityId,
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.invoiceDate,
      contactId: invoice.contactId,
      totalAmountCents: invoice.totalAmountCents,
      totalGstCents: invoice.totalGstCents,
      bankAccountId: invoice.bankAccountId,
      paidAt: invoice.paidAt,
      createdAt: invoice.createdAt,
      updatedAt: invoice.updatedAt,
      lineItems: lineItems,
    );
  }

  @override
  Future<Invoice> markPaid(
    String id, {
    required String entityId,
    required DateTime paidAt,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE invoices
        SET paid_at    = @paidAt,
            updated_at = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND paid_at IS NULL
        RETURNING
          id, entity_id, invoice_number, invoice_date,
          contact_id, total_amount_cents, total_gst_cents,
          bank_account_id, paid_at, created_at, updated_at
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'paidAt': paidAt.toIso8601String(),
      },
    );

    if (result.isEmpty) {
      throw Exception('Invoice not found or already paid');
    }

    return _mapInvoiceRow(result.first.toColumnMap());
  }

  @override
  Future<List<String>> findInvoiceNumbersLike(String pattern,
      {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT DISTINCT invoice_number
        FROM invoices
        WHERE entity_id = @entityId
          AND invoice_number LIKE @pattern
      '''),
      parameters: {'entityId': entityId, 'pattern': pattern},
    );
    return result.map((r) => r[0] as String).toList();
  }

  @override
  Future<Invoice> update({
    required String id,
    required String entityId,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<InvoiceLineItemInput> lineItems,
    String? bankAccountId,
  }) async {
    final totalAmountCents =
        lineItems.fold(0, (sum, i) => sum + i.amountCents);
    final totalGstCents = lineItems.fold(0, (sum, i) => sum + i.gstCents);
    final invoiceDateStr =
        invoiceDate.toIso8601String().substring(0, 10);

    return await _pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named('''
          UPDATE invoices
          SET invoice_number     = @invoiceNumber,
              invoice_date       = @invoiceDate::date,
              total_amount_cents = @totalAmountCents,
              total_gst_cents    = @totalGstCents,
              bank_account_id    = @bankAccountId::uuid,
              updated_at         = NOW()
          WHERE id = @id::uuid
            AND entity_id = @entityId
            AND paid_at IS NULL
          RETURNING
            id, entity_id, invoice_number, invoice_date,
            contact_id, total_amount_cents, total_gst_cents,
            bank_account_id, paid_at, created_at, updated_at
        '''),
        parameters: {
          'id': id,
          'entityId': entityId,
          'invoiceNumber': invoiceNumber,
          'invoiceDate': invoiceDateStr,
          'totalAmountCents': totalAmountCents,
          'totalGstCents': totalGstCents,
          'bankAccountId': bankAccountId,
        },
      );

      if (rows.isEmpty) {
        throw Exception('Invoice not found or already paid');
      }

      await tx.execute(
        Sql.named('''
          DELETE FROM invoice_line_items
          WHERE invoice_id = @invoiceId::uuid
            AND entity_id = @entityId
        '''),
        parameters: {'invoiceId': id, 'entityId': entityId},
      );

      final createdLineItems = <InvoiceLineItem>[];
      for (final item in lineItems) {
        final itemId = _uuid.v4();
        final itemRows = await tx.execute(
          Sql.named('''
            INSERT INTO invoice_line_items (
              id, entity_id, invoice_id, description,
              general_ledger_id, amount_cents, gst_cents
            )
            VALUES (
              @id::uuid, @entityId, @invoiceId::uuid, @description,
              @generalLedgerId::uuid, @amountCents, @gstCents
            )
            RETURNING
              id, invoice_id, description, general_ledger_id,
              amount_cents, gst_cents, created_at
          '''),
          parameters: {
            'id': itemId,
            'entityId': entityId,
            'invoiceId': id,
            'description': item.description,
            'generalLedgerId': item.generalLedgerId,
            'amountCents': item.amountCents,
            'gstCents': item.gstCents,
          },
        );
        createdLineItems.add(_mapLineItemRow(itemRows.first.toColumnMap()));
      }

      final invoice = _mapInvoiceRow(rows.first.toColumnMap());
      return Invoice(
        id: invoice.id,
        entityId: invoice.entityId,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.invoiceDate,
        contactId: invoice.contactId,
        totalAmountCents: invoice.totalAmountCents,
        totalGstCents: invoice.totalGstCents,
        bankAccountId: invoice.bankAccountId,
        paidAt: invoice.paidAt,
        createdAt: invoice.createdAt,
        updatedAt: invoice.updatedAt,
        lineItems: createdLineItems,
      );
    });
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        DELETE FROM invoices
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND paid_at IS NULL
        RETURNING id
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.isEmpty) {
      throw Exception('Invoice not found or already paid');
    }
  }

  // ── Mapping helpers ───────────────────────────────────────────────────────

  Invoice _mapInvoiceRow(Map<String, dynamic> row) {
    final invoiceDate = row['invoice_date'] as DateTime;
    final rawBankAccountId = row['bank_account_id'];
    return Invoice(
      id: row['id'].toString(),
      entityId: row['entity_id'] as String,
      invoiceNumber: row['invoice_number'] as String,
      invoiceDate: DateTime.utc(
          invoiceDate.year, invoiceDate.month, invoiceDate.day),
      contactId: row['contact_id'].toString(),
      totalAmountCents: row['total_amount_cents'] as int,
      totalGstCents: row['total_gst_cents'] as int,
      bankAccountId: rawBankAccountId != null ? rawBankAccountId.toString() : null,
      paidAt: row['paid_at'] as DateTime?,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  InvoiceLineItem _mapLineItemRow(Map<String, dynamic> row) {
    return InvoiceLineItem(
      id: row['id'].toString(),
      invoiceId: row['invoice_id'].toString(),
      description: row['description'] as String,
      generalLedgerId: row['general_ledger_id'].toString(),
      amountCents: row['amount_cents'] as int,
      gstCents: row['gst_cents'] as int,
      createdAt: row['created_at'] as DateTime,
    );
  }
}
