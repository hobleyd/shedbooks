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

/// One-time (idempotent) data-migration script: reads each member's encrypted
/// `emergency_contact` value, splits it into a name and a phone number, then
/// writes the encrypted parts into `emergency_contact_name` and
/// `emergency_contact_phone`.
///
/// Run after migration 040 has been applied:
///   dart run bin/split_emergency_contacts.dart
///
/// The script re-derives the split from the source column on every run, so it
/// is safe to run multiple times (e.g. after fixing the heuristic).
///
/// Phone detection heuristic: an Australian phone number is exactly 10
/// consecutive digits beginning with 0 (\b0\d{9}\b).  The phone is extracted
/// from wherever it appears in the string; everything else (whitespace
/// collapsed) becomes the name.
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../lib/infrastructure/database/database_connection.dart';
import '../lib/infrastructure/encryption/field_encryptor.dart';

/// Splits [value] into (name, phone).
///
/// Returns (null, null) for null/empty input.
/// If a 10-digit Australian number is found it becomes the phone; the
/// remainder (whitespace collapsed and trimmed) becomes the name.
/// If no number is found the whole string becomes the name.
(String?, String?) splitEmergencyContact(String? value) {
  if (value == null) return (null, null);
  final trimmed = value.trim();
  if (trimmed.isEmpty) return (null, null);

  final phoneRe = RegExp(r'\b0\d{9}\b');
  final match = phoneRe.firstMatch(trimmed);

  if (match == null) {
    return (trimmed, null);
  }

  final phone = match.group(0)!;
  final withoutPhone = trimmed
      .substring(0, match.start)
      .trim() +
      ' ' +
      trimmed.substring(match.end).trim();
  final name = withoutPhone.trim().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return (name.isEmpty ? null : name, phone);
}

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level.name} ${r.message}'));
  final log = Logger('split_emergency_contacts');

  final encryptionKey = Platform.environment['ENCRYPTION_KEY'];
  if (encryptionKey == null || encryptionKey.isEmpty) {
    log.severe('ENCRYPTION_KEY environment variable is not set');
    exit(1);
  }

  final enc = FieldEncryptor(encryptionKey);
  final pool = DatabaseConnection.pool;

  try {
    final rows = await pool.execute(
      'SELECT id, emergency_contact FROM members WHERE deleted_at IS NULL',
    );
    log.info('Processing ${rows.length} member rows');

    int updated = 0;
    for (final row in rows) {
      final map = row.toColumnMap();
      final id = map['id'].toString();
      final raw = map['emergency_contact'] as String?;

      final decrypted = raw != null ? enc.decrypt(raw) : null;
      final (name, phone) = splitEmergencyContact(decrypted);

      await pool.execute(
        Sql.named('''
          UPDATE members
          SET emergency_contact_name  = @name,
              emergency_contact_phone = @phone,
              updated_at              = NOW()
          WHERE id = @id::uuid
        '''),
        parameters: {
          'id': id,
          'name': name != null ? enc.encrypt(name) : null,
          'phone': phone != null ? enc.encrypt(phone) : null,
        },
      );
      updated++;
      log.info('Updated member $id: name=${name ?? "(null)"}, phone=${phone ?? "(null)"}');
    }

    log.info('Done — updated $updated rows');
  } finally {
    await DatabaseConnection.dispose();
  }
}
