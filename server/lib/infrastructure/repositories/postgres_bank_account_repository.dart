import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/bank_account.dart';
import '../../domain/exceptions/bank_account_exception.dart';
import '../../domain/repositories/i_bank_account_repository.dart';
import '../encryption/field_encryptor.dart';

/// PostgreSQL implementation of [IBankAccountRepository].
class PostgresBankAccountRepository implements IBankAccountRepository {
  final Pool _pool;
  final Uuid _uuid;
  final FieldEncryptor _enc;

  PostgresBankAccountRepository(this._pool, FieldEncryptor encryptor, [Uuid? uuid])
      : _enc = encryptor,
        _uuid = uuid ?? const Uuid();

  static const _cols =
      'id, entity_id, bank_name, account_name, bsb, account_number, '
      'account_type, currency, created_at, updated_at';

  @override
  Future<BankAccount> create({
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  }) async {
    final id = _uuid.v4();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO bank_accounts
          (id, entity_id, bank_name, account_name, bsb, account_number, account_type, currency)
        VALUES
          (@id::uuid, @entityId, @bankName, @accountName, @bsb, @accountNumber, @accountType, @currency)
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'bankName': _enc.encrypt(bankName),
        'accountName': _enc.encrypt(accountName),
        'bsb': _enc.encrypt(bsb),
        'accountNumber': _enc.encrypt(accountNumber),
        'accountType': _typeToDb(accountType),
        'currency': currency,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<BankAccount?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols FROM bank_accounts
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<BankAccount>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols FROM bank_accounts
        WHERE entity_id = @entityId AND deleted_at IS NULL
        ORDER BY bank_name ASC, account_name ASC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((r) => _mapRow(r.toColumnMap())).toList();
  }

  @override
  Future<BankAccount> update({
    required String id,
    required String entityId,
    required String bankName,
    required String accountName,
    required String bsb,
    required String accountNumber,
    required BankAccountType accountType,
    required String currency,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE bank_accounts
        SET bank_name      = @bankName,
            account_name   = @accountName,
            bsb            = @bsb,
            account_number = @accountNumber,
            account_type   = @accountType,
            currency       = @currency,
            updated_at     = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'bankName': _enc.encrypt(bankName),
        'accountName': _enc.encrypt(accountName),
        'bsb': _enc.encrypt(bsb),
        'accountNumber': _enc.encrypt(accountNumber),
        'accountType': _typeToDb(accountType),
        'currency': currency,
      },
    );
    if (result.isEmpty) throw BankAccountNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE bank_accounts
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.affectedRows == 0) throw BankAccountNotFoundException(id);
  }

  static String _typeToDb(BankAccountType t) => switch (t) {
        BankAccountType.transaction => 'transaction',
        BankAccountType.savings => 'savings',
        BankAccountType.termDeposit => 'term_deposit',
      };

  static BankAccountType _typeFromDb(String v) => switch (v) {
        'savings' => BankAccountType.savings,
        'term_deposit' => BankAccountType.termDeposit,
        _ => BankAccountType.transaction,
      };

  BankAccount _mapRow(Map<String, dynamic> row) => BankAccount(
        id: row['id'].toString(),
        entityId: row['entity_id'] as String,
        bankName: _enc.decrypt(row['bank_name'] as String),
        accountName: _enc.decrypt(row['account_name'] as String),
        bsb: _enc.decrypt((row['bsb'] as String).trim()),
        accountNumber: _enc.decrypt(row['account_number'] as String),
        accountType: _typeFromDb(row['account_type'] as String),
        currency: (row['currency'] as String).trim(),
        createdAt: row['created_at'] as DateTime,
        updatedAt: row['updated_at'] as DateTime,
      );
}
