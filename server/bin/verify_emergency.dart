import 'dart:io';
import '../lib/infrastructure/encryption/field_encryptor.dart';
import '../lib/infrastructure/database/database_connection.dart';

void main() async {
  final enc = FieldEncryptor(Platform.environment['ENCRYPTION_KEY']!);
  final pool = DatabaseConnection.pool;
  try {
    final rows = await pool.execute(
      'SELECT last_name, first_name, emergency_contact_name, emergency_contact_phone '
      'FROM members WHERE deleted_at IS NULL AND emergency_contact_phone IS NOT NULL LIMIT 5',
    );
    for (final row in rows) {
      final m = row.toColumnMap();
      try {
        final name = enc.decrypt(m['emergency_contact_name'] as String);
        final phone = enc.decrypt(m['emergency_contact_phone'] as String);
        print('${m["last_name"]}, ${m["first_name"]}: name=$name phone=$phone');
      } catch (e) {
        print('${m["last_name"]}, ${m["first_name"]}: DECRYPT ERROR: $e');
      }
    }
  } finally {
    await DatabaseConnection.dispose();
  }
}
