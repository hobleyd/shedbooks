/// One-time script: encrypts any plaintext bank account sensitive fields.
///
/// Run from the server directory with DB and ENCRYPTION_KEY env vars set:
///   dart run bin/encrypt_bank_accounts.dart
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
  final log = Logger('encrypt_bank_accounts');

  final encryptionKey = Platform.environment['ENCRYPTION_KEY'];
  if (encryptionKey == null || encryptionKey.isEmpty) {
    log.severe('ENCRYPTION_KEY environment variable is not set');
    exit(1);
  }

  final enc = FieldEncryptor(encryptionKey);
  final pool = DatabaseConnection.pool;

  try {
    final rows = await pool.execute(
      'SELECT id, bank_name, account_name, bsb, account_number FROM bank_accounts WHERE deleted_at IS NULL',
    );

    log.info('Found ${rows.length} bank account row(s) to inspect');
    int updated = 0;

    for (final row in rows) {
      final map = row.toColumnMap();
      final id = map['id'].toString();
      final bankName = map['bank_name'] as String;
      final accountName = map['account_name'] as String;
      final bsb = map['bsb'] as String;
      final accountNumber = map['account_number'] as String;

      final needsEncryption = !bankName.startsWith('enc:') ||
          !accountName.startsWith('enc:') ||
          !bsb.trim().startsWith('enc:') ||
          !accountNumber.startsWith('enc:');

      if (!needsEncryption) {
        log.info('Row $id already encrypted — skipping');
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
          'bsb': bsb.trim().startsWith('enc:') ? bsb : enc.encrypt(bsb),
          'accountNumber': accountNumber.startsWith('enc:') ? accountNumber : enc.encrypt(accountNumber),
        },
      );

      log.info('Encrypted row $id');
      updated++;
    }

    log.info('Done — $updated row(s) encrypted, ${rows.length - updated} already encrypted');
  } finally {
    await DatabaseConnection.dispose();
  }
}
