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
import '../../domain/entities/transaction_line.dart';
import '../../domain/exceptions/transaction_exception.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// PostgreSQL implementation of [ITransactionRepository].
class PostgresTransactionRepository implements ITransactionRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresTransactionRepository(this._pool, [Uuid? uuid])
      : _uuid = uuid ?? const Uuid();

  static const String _columns = '''
    id, contact_id, general_ledger_id, amount, gst_amount,
    transaction_type::text, receipt_number, payment_reference, description, transaction_date,
    created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name,
    bank_account_id, split_group_id, split_line_no''';

  @override
  Future<Transaction> create({
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
    String? bankAccountId,
  }) async {
    try {
      return await _insert(
        _pool,
        entityId: entityId,
        contactId: contactId,
        generalLedgerId: generalLedgerId,
        amount: amount,
        gstAmount: gstAmount,
        transactionType: transactionType,
        receiptNumber: receiptNumber,
        paymentReference: paymentReference,
        description: description,
        transactionDate: transactionDate,
        isCash: isCash,
        bankMatched: isCash,
        bankAccountId: bankAccountId,
      );
    } on ServerException catch (e) {
      _rethrowIfFkViolation(e);
      rethrow;
    }
  }

  @override
  Future<List<Transaction>> createSplit({
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    bool isCash = false,
    String? bankAccountId,
    required List<TransactionLine> lines,
  }) async {
    try {
      return await _pool.runTx((tx) => _insertLines(
            tx,
            entityId: entityId,
            contactId: contactId,
            transactionType: transactionType,
            receiptNumber: receiptNumber,
            paymentReference: paymentReference,
            transactionDate: transactionDate,
            isCash: isCash,
            bankMatched: isCash,
            bankAccountId: bankAccountId,
            lines: lines,
          ));
    } on ServerException catch (e) {
      _rethrowIfFkViolation(e);
      rethrow;
    }
  }

  @override
  Future<List<Transaction>> replaceWithLines({
    required List<String> replacedIds,
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    bool isCash = false,
    bool bankMatched = false,
    String? abaBatchName,
    String? bankAccountId,
    required List<TransactionLine> lines,
  }) async {
    try {
      return await _pool.runTx((tx) async {
        for (final id in replacedIds) {
          await tx.execute(
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
        }
        return _insertLines(
          tx,
          entityId: entityId,
          contactId: contactId,
          transactionType: transactionType,
          receiptNumber: receiptNumber,
          paymentReference: paymentReference,
          transactionDate: transactionDate,
          isCash: isCash,
          bankMatched: bankMatched,
          abaBatchName: abaBatchName,
          bankAccountId: bankAccountId,
          lines: lines,
        );
      });
    } on ServerException catch (e) {
      _rethrowIfFkViolation(e);
      rethrow;
    }
  }

  @override
  Future<List<Transaction>> findBySplitGroup(String splitGroupId,
      {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_columns
        FROM transactions
        WHERE split_group_id = @splitGroupId::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY split_line_no
      '''),
      parameters: {'splitGroupId': splitGroupId, 'entityId': entityId},
    );

    return result.map((row) => _mapRow(row.toColumnMap())).toList();
  }

  @override
  Future<void> deleteSplitGroup(String splitGroupId,
      {required String entityId}) async {
    await _pool.execute(
      Sql.named('''
        UPDATE transactions
        SET deleted_at = NOW(),
            updated_at = NOW()
        WHERE split_group_id = @splitGroupId::uuid
          AND entity_id = @entityId
          AND deleted_at IS NULL
      '''),
      parameters: {'splitGroupId': splitGroupId, 'entityId': entityId},
    );
  }

  /// Inserts [lines] as transaction rows on [session]. More than one line is
  /// written as a split sharing a new split group id; a single line is
  /// written as an ordinary transaction.
  Future<List<Transaction>> _insertLines(
    Session session, {
    required String entityId,
    required String contactId,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required DateTime transactionDate,
    required bool isCash,
    required bool bankMatched,
    String? abaBatchName,
    String? bankAccountId,
    required List<TransactionLine> lines,
  }) async {
    final String? splitGroupId = lines.length > 1 ? _uuid.v4() : null;
    final List<Transaction> created = [];
    for (int i = 0; i < lines.length; i++) {
      final TransactionLine line = lines[i];
      created.add(await _insert(
        session,
        entityId: entityId,
        contactId: contactId,
        generalLedgerId: line.generalLedgerId,
        amount: line.amount,
        gstAmount: line.gstAmount,
        transactionType: transactionType,
        receiptNumber: receiptNumber,
        paymentReference: paymentReference,
        description: line.description,
        transactionDate: transactionDate,
        isCash: isCash,
        bankMatched: bankMatched,
        abaBatchName: abaBatchName,
        bankAccountId: bankAccountId,
        splitGroupId: splitGroupId,
        splitLineNo: splitGroupId == null ? null : i + 1,
      ));
    }
    return created;
  }

  /// Inserts a single transaction row on [session] (the pool, or an open
  /// database transaction) and returns the persisted entity.
  Future<Transaction> _insert(
    Session session, {
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    String? paymentReference,
    required String description,
    required DateTime transactionDate,
    required bool isCash,
    required bool bankMatched,
    String? abaBatchName,
    String? bankAccountId,
    String? splitGroupId,
    int? splitLineNo,
  }) async {
    final result = await session.execute(
      Sql.named('''
        INSERT INTO transactions (
          id, entity_id, contact_id, general_ledger_id, amount, gst_amount,
          transaction_type, receipt_number, payment_reference, description, transaction_date,
          is_cash, bank_matched, aba_batch_name, bank_account_id,
          split_group_id, split_line_no
        )
        VALUES (
          @id::uuid, @entityId::text, @contactId::uuid, @generalLedgerId::uuid,
          @amount, @gstAmount, @transactionType::transaction_type,
          @receiptNumber, @paymentReference, @description, @transactionDate::date,
          @isCash, @bankMatched, @abaBatchName,
          (SELECT id FROM bank_accounts
           WHERE id = @bankAccountId::uuid AND entity_id = @entityId::text AND deleted_at IS NULL),
          @splitGroupId::uuid, @splitLineNo
        )
        RETURNING $_columns
      '''),
      parameters: {
        'id': _uuid.v4(),
        'entityId': entityId,
        'contactId': contactId,
        'generalLedgerId': generalLedgerId,
        'amount': amount,
        'gstAmount': gstAmount,
        'transactionType': transactionType.name,
        'receiptNumber': receiptNumber,
        'paymentReference': paymentReference,
        'description': description,
        'transactionDate': transactionDate.toIso8601String().substring(0, 10),
        'isCash': isCash,
        'bankMatched': bankMatched,
        'abaBatchName': abaBatchName,
        'bankAccountId': bankAccountId,
        'splitGroupId': splitGroupId,
        'splitLineNo': splitLineNo,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<Transaction?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT
          id, contact_id, general_ledger_id, amount, gst_amount,
          transaction_type::text, receipt_number, payment_reference, description, transaction_date,
          created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name,
          bank_account_id, split_group_id, split_line_no
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
          transaction_type::text, receipt_number, payment_reference, description, transaction_date,
          created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name,
          bank_account_id, split_group_id, split_line_no
        FROM transactions
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
        ORDER BY transaction_date DESC, created_at DESC, split_line_no
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
    String? paymentReference,
    required String description,
    required DateTime transactionDate,
    bool isCash = false,
    bool bankMatched = false,
    String? bankAccountId,
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
              payment_reference = @paymentReference,
              description       = @description,
              transaction_date  = @transactionDate::date,
              is_cash           = @isCash,
              bank_matched      = @bankMatched,
              bank_account_id   = (SELECT id FROM bank_accounts
                                    WHERE id = @bankAccountId::uuid AND entity_id = @entityId::text AND deleted_at IS NULL),
              updated_at        = NOW()
          WHERE id = @id::uuid
            AND entity_id = @entityId::text
            AND deleted_at IS NULL
          RETURNING
            id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type::text, receipt_number, payment_reference, description, transaction_date,
            created_at, updated_at, deleted_at, bank_matched, is_cash, aba_batch_name,
            bank_account_id, split_group_id, split_line_no
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
          'paymentReference': paymentReference,
          'description': description,
          'transactionDate': transactionDate.toIso8601String().substring(0, 10),
          'isCash': isCash,
          'bankMatched': bankMatched,
          'bankAccountId': bankAccountId,
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
  Future<void> bankMatch(
    List<String> ids, {
    required String entityId,
    String? bankAccountId,
    DateTime? transactionDate,
  }) async {
    if (ids.isEmpty) return;
    final transactionDateParam =
        transactionDate?.toIso8601String().substring(0, 10);
    await _pool.runTx((tx) async {
      for (final id in ids) {
        await tx.execute(
          Sql.named('''
            UPDATE transactions
            SET bank_matched    = TRUE,
                bank_account_id = (SELECT id FROM bank_accounts
                                    WHERE id = @bankAccountId::uuid AND entity_id = @entityId::text AND deleted_at IS NULL),
                transaction_date = COALESCE(@transactionDate::date, transaction_date),
                updated_at      = NOW()
            WHERE (id = @id::uuid OR split_group_id = (
                    SELECT split_group_id FROM transactions
                    WHERE id = @id::uuid AND entity_id = @entityId::text))
              AND entity_id = @entityId::text
              AND deleted_at IS NULL
          '''),
          parameters: {
            'id': id,
            'entityId': entityId,
            'bankAccountId': bankAccountId,
            'transactionDate': transactionDateParam,
          },
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
      paymentReference: row['payment_reference'] as String?,
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
      bankAccountId: row['bank_account_id']?.toString(),
      splitGroupId: row['split_group_id']?.toString(),
      splitLineNo: row['split_line_no'] as int?,
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
            WHERE (id = @id::uuid OR split_group_id = (
                    SELECT split_group_id FROM transactions
                    WHERE id = @id::uuid AND entity_id = @entityId))
              AND entity_id = @entityId
              AND deleted_at IS NULL
          '''),
          parameters: {'id': id, 'entityId': entityId, 'batchName': batchName},
        );
      }
    });
  }

}
