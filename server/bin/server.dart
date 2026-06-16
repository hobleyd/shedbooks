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

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/infrastructure/database/database_connection.dart';
import '../lib/infrastructure/database/database_migrator.dart';
import '../lib/infrastructure/encryption/field_encryptor.dart';
import '../lib/presentation/router.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name} [${record.loggerName}] ${record.message}'
        '${record.error != null ? '\n${record.error}' : ''}'
        '${record.stackTrace != null ? '\n${record.stackTrace}' : ''}');
  });

  final log = Logger('Server');

  try {
    await DatabaseMigrator(DatabaseConnection.pool).migrate();
  } catch (e, st) {
    log.severe('Migration failed — aborting startup', e, st);
    exit(1);
  }

  final auth0Domain = _require('AUTH0_DOMAIN');
  final audience = _require('AUTH0_AUDIENCE');
  final corsOrigin = Platform.environment['CORS_ORIGIN'] ?? '*';
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final abrGuid = Platform.environment['ABR_GUID'] ?? '';
  final encryptionKey = _require('ENCRYPTION_KEY');
  final fieldEncryptor = FieldEncryptor(encryptionKey);

  final handler = buildRouter(
    auth0Domain: auth0Domain,
    audience: audience,
    corsOrigin: corsOrigin,
    fieldEncryptor: fieldEncryptor,
    abrGuid: abrGuid,
  );

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  log.info('Server listening on port ${server.port}');
}

String _require(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError('Required environment variable $key is not set');
  }
  return value;
}
