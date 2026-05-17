/// One-time script: encrypts any plaintext sensitive fields in bank_accounts,
/// contacts, and entity_details.
///
/// Run from the server directory with DB and ENCRYPTION_KEY env vars set:
///   dart run bin/encrypt_sensitive_fields.dart
///
/// Safe to run multiple times — already-encrypted values (prefixed with
/// "enc:") are skipped.
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../lib/infrastructure/database/database_connection.dart';
import '../lib/infrastructure/encryption/field_encryptor.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level.name} ${r.message}'));
  final log = Logger('encrypt_sensitive_fields');

  final encryptionKey = Platform.environment['ENCRYPTION_KEY'];
  if (encryptionKey == null || encryptionKey.isEmpty) {
    log.severe('ENCRYPTION_KEY environment variable is not set');
    exit(1);
  }

  final enc = FieldEncryptor(encryptionKey);
  final pool = DatabaseConnection.pool;

  try {
    // 1. bank_accounts
    final baRows = await pool.execute(
      'SELECT id, bank_name, account_name, bsb, account_number FROM bank_accounts WHERE deleted_at IS NULL',
    );
    log.info('Inspecting ${baRows.length} bank_accounts rows');
    for (final row in baRows) {
      final map = row.toColumnMap();
      final id = map['id'].toString();
      final bankName = map['bank_name'] as String;
      final accountName = map['account_name'] as String;
      final bsb = map['bsb'] as String;
      final accountNumber = map['account_number'] as String;

      if (bankName.startsWith('enc:') && accountName.startsWith('enc:') && bsb.trim().startsWith('enc:') && accountNumber.startsWith('enc:')) {
        continue;
      }

      await pool.execute(
        Sql.named('''
          UPDATE bank_accounts
          SET bank_name      = @bankName,
              account_name   = @accountName,
              bsb            = @bsb,
              account_number = @accountNumber,
              updated_at     = NOW()
          WHERE id = @id::uuid
        '''),
        parameters: {
          'id': id,
          'bankName': bankName.startsWith('enc:') ? bankName : enc.encrypt(bankName),
          'accountName': accountName.startsWith('enc:') ? accountName : enc.encrypt(accountName),
          'bsb': bsb.trim().startsWith('enc:') ? bsb : enc.encrypt(bsb.trim()),
          'accountNumber': accountNumber.startsWith('enc:') ? accountNumber : enc.encrypt(accountNumber),
        },
      );
      log.info('Encrypted bank_accounts row $id');
    }

    // 2. contacts
    final cRows = await pool.execute(
      'SELECT id, bsb, account_number FROM contacts WHERE deleted_at IS NULL',
    );
    log.info('Inspecting ${cRows.length} contacts rows');
    for (final row in cRows) {
      final map = row.toColumnMap();
      final id = map['id'].toString();
      final bsb = map['bsb'] as String?;
      final accountNumber = map['account_number'] as String?;

      if ((bsb == null || bsb.startsWith('enc:')) && (accountNumber == null || accountNumber.startsWith('enc:'))) {
        continue;
      }

      await pool.execute(
        Sql.named('''
          UPDATE contacts
          SET bsb            = @bsb,
              account_number = @accountNumber,
              updated_at     = NOW()
          WHERE id = @id::uuid
        '''),
        parameters: {
          'id': id,
          'bsb': (bsb == null || bsb.startsWith('enc:')) ? bsb : enc.encrypt(bsb.trim()),
          'accountNumber': (accountNumber == null || accountNumber.startsWith('enc:')) ? accountNumber : enc.encrypt(accountNumber.trim()),
        },
      );
      log.info('Encrypted contacts row $id');
    }

    // 3. entity_details
    final edRows = await pool.execute(
      'SELECT entity_id, apca_id FROM entity_details',
    );
    log.info('Inspecting ${edRows.length} entity_details rows');
    for (final row in edRows) {
      final map = row.toColumnMap();
      final id = map['entity_id'] as String;
      final apcaId = map['apca_id'] as String?;

      if (apcaId == null || apcaId.startsWith('enc:')) {
        continue;
      }

      await pool.execute(
        Sql.named('''
          UPDATE entity_details
          SET apca_id    = @apcaId,
              updated_at = NOW()
          WHERE entity_id = @id
        '''),
        parameters: {
          'id': id,
          'apcaId': enc.encrypt(apcaId.trim()),
        },
      );
      log.info('Encrypted entity_details row $id');
    }

    log.info('Done');
  } finally {
    await DatabaseConnection.dispose();
  }
}
