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

import '../../domain/entities/transaction.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// PostgreSQL implementation of [ITransactionRepository].
class PostgresTransactionRepository implements ITransactionRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresTransactionRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  @override
  Future<Transaction> create({
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
  }) async {
    try {
      final id = _uuid.v4();
      final result = await _pool.execute(
        Sql.named('''
          INSERT INTO transactions (
            id, entity_id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type, receipt_number, description, transaction_date,
            is_cash, bank_matched
          )
          VALUES (
            @id::uuid, @entityId, @contactId::uuid, @generalLedgerId::uuid,
            @amount, @gstAmount, @transactionType::transaction_type,
            @receiptNumber, @description, @transactionDate::date,
            @isCash, @isCash
          )
          RETURNING
            id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type::text, receipt_number, description, transaction_date,
            created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name
        '''),
        parameters: {
          'id': id,
          'entityId': entityId,
          'contactId': contactId,
          'generalLedgerId': generalLedgerId,
          'amount': amount,
          'gstAmount': gstAmount,
          'transactionType': transactionType.name,
          'receiptNumber': receiptNumber,
          'description': description,
          'transactionDate': transactionDate.toIso8601String().substring(0, 10),
          'isCash': isCash,
        },
      );
      return _mapRow(result.first.toColumnMap());
    } on ServerException catch (e) {
      _rethrowIfFkViolation(e);
      rethrow;
    }
  }

  @override
  Future<Transaction?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT
          id, contact_id, general_ledger_id, amount, gst_amount,
          transaction_type::text, receipt_number, description, transaction_date,
          created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name
        FROM transactions
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<Transaction>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT
          id, contact_id, general_ledger_id, amount, gst_amount,
          transaction_type::text, receipt_number, description, transaction_date,
          created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name
        FROM transactions
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY transaction_date DESC, created_at DESC
      '''),
      parameters: {'entityId': entityId},
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<Transaction> update({
    required String id,
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
    bool bankMatched = false,
  }) async {
    try {
      final result = await _pool.execute(
        Sql.named('''
          UPDATE transactions
          SET contact_id        = @contactId::uuid,
              general_ledger_id = @generalLedgerId::uuid,
              amount            = @amount,
              gst_amount        = @gstAmount,
              transaction_type  = @transactionType::transaction_type,
              receipt_number    = @receiptNumber,
              description       = @description,
              transaction_date  = @transactionDate::date,
              is_cash           = @isCash,
              bank_matched      = @bankMatched,
              updated_at        = NOW()
          WHERE id = @id::uuid
            AND entity_id = @entityId
            AND deleted_at IS NULL
          RETURNING
            id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type::text, receipt_number, description, transaction_date,
            created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name
        '''),
        parameters: {
          'id': id,
          'entityId': entityId,
          'contactId': contactId,
          'generalLedgerId': generalLedgerId,
          'amount': amount,
          'gstAmount': gstAmount,
          'transactionType': transactionType.name,
          'receiptNumber': receiptNumber,
          'description': description,
          'transactionDate': transactionDate.toIso8601String().substring(0, 10),
          'isCash': isCash,
          'bankMatched': bankMatched,
        },
      );

      if (result.isEmpty) throw TransactionNotFoundException(id);
      return _mapRow(result.first.toColumnMap());
    } on ServerException catch (e) {
      _rethrowIfFkViolation(e);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE transactions
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE id = @id::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );

    if (result.affectedRows == 0) throw TransactionNotFoundException(id);
  }

  @override
  Future<bool> hasTransactions(String contactId,
      {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT EXISTS(
          SELECT 1 FROM transactions
          WHERE contact_id = @contactId::uuid
            AND entity_id = @entityId
            AND deleted_at IS NULL
        ) AS has_transactions
      '''),
      parameters: {'contactId': contactId, 'entityId': entityId},
    );
    return result.first.toColumnMap()['has_transactions'] as bool;
  }

  @override
  Future<void> reassignContact(
    List<String> fromContactIds,
    String toContactId, {
    required String entityId,
  }) async {
    if (fromContactIds.isEmpty) return;
    await _pool.execute(
      Sql.named('''
        UPDATE transactions
        SET contact_id = @toId::uuid,
            updated_at = NOW()
        WHERE contact_id = ANY(string_to_array(@fromIds, ',')::uuid[])
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {
        'toId': toContactId,
        'fromIds': fromContactIds.join(','),
        'entityId': entityId,
      },
    );
  }

  static void _rethrowIfFkViolation(ServerException e) {
    if (e.code != '23503') return;
    switch (e.constraintName) {
      case 'fk_transactions_contact':
        throw const TransactionValidationException(
          'Referenced contact does not exist',
        );
      case 'fk_transactions_general_ledger':
        throw const TransactionValidationException(
          'Referenced general ledger account does not exist',
        );
      default:
        throw const TransactionValidationException(
          'A referenced record does not exist',
        );
    }
  }

  @override
  Future<void> bankMatch(List<String> ids, {required String entityId}) async {
    if (ids.isEmpty) return;
    await _pool.runTx((tx) async {
      for (final id in ids) {
        await tx.execute(
          Sql.named('''
            UPDATE transactions
            SET bank_matched = TRUE,
                updated_at   = NOW()
            WHERE id = @id::uuid
              AND entity_id = @entityId
              AND deleted_at IS NULL
          '''),
          parameters: {'id': id, 'entityId': entityId},
        );
      }
    });
  }

  Transaction _mapRow(Map<String, dynamic> row) {
    final transactionDate = row['transaction_date'] as DateTime;

    return Transaction(
      id: row['id'].toString(),
      contactId: row['contact_id'].toString(),
      generalLedgerId: row['general_ledger_id'].toString(),
      amount: row['amount'] as int,
      gstAmount: row['gst_amount'] as int,
      transactionType: TransactionType.values.byName(
        row['transaction_type'] as String,
      ),
      receiptNumber: row['receipt_number'] as String,
      description: row['description'] as String,
      transactionDate: DateTime.utc(
        transactionDate.year,
        transactionDate.month,
        transactionDate.day,
      ),
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
      bankMatched: row['bank_matched'] as bool? ?? false,
      isCash: row['is_cash'] as bool? ?? false,
      abaBatchName: row['aba_batch_name'] as String?,
    );
  }

  @override
  Future<void> stampAbaBatch(
    List<String> ids,
    String batchName, {
    required String entityId,
  }) async {
    if (ids.isEmpty) return;
    await _pool.runTx((tx) async {
      for (final id in ids) {
        await tx.execute(
          Sql.named('''
            UPDATE transactions
            SET aba_batch_name = @batchName,
                updated_at     = NOW()
            WHERE id = @id::uuid
              AND entity_id = @entityId
              AND deleted_at IS NULL
          '''),
          parameters: {'id': id, 'entityId': entityId, 'batchName': batchName},
        );
      }
    });
  }

  @override
  Future<List<String>> findReceiptNumbersLike(String pattern,
      {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT DISTINCT receipt_number
        FROM transactions
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
          AND receipt_number LIKE @pattern
      '''),
      parameters: {'entityId': entityId, 'pattern': pattern},
    );
    return result.map((r) => r[0] as String).toList();
  }
}
