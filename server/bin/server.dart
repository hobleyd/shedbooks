import 'dart:io';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

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

  final auth0Domain = _require('AUTH0_DOMAIN');
  final audience = _require('AUTH0_AUDIENCE');
  final corsOrigin = Platform.environment['CORS_ORIGIN'] ?? '*';
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final abrGuid = Platform.environment['ABR_GUID'] ?? '';

  final handler = buildRouter(
    auth0Domain: auth0Domain,
    audience: audience,
    corsOrigin: corsOrigin,
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
