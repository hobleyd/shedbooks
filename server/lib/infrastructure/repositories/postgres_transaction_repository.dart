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
  }) async {
    try {
      final id = _uuid.v4();
      final result = await _pool.execute(
        Sql.named('''
          INSERT INTO transactions (
            id, entity_id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type, receipt_number, description, transaction_date
          )
          VALUES (
            @id::uuid, @entityId, @contactId::uuid, @generalLedgerId::uuid,
            @amount, @gstAmount, @transactionType::transaction_type,
            @receiptNumber, @description, @transactionDate::date
          )
          RETURNING
            id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type::text, receipt_number, description, transaction_date,
            created_at, updated_at, deleted_at
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
          created_at, updated_at, deleted_at
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
          created_at, updated_at, deleted_at
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
              updated_at        = NOW()
          WHERE id = @id::uuid
            AND entity_id = @entityId
            AND deleted_at IS NULL
          RETURNING
            id, contact_id, general_ledger_id, amount, gst_amount,
            transaction_type::text, receipt_number, description, transaction_date,
            created_at, updated_at, deleted_at
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
    );
  }
}
