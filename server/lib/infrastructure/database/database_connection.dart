import 'dart:io';
import 'package:postgres/postgres.dart';

/// Provides a lazily-initialised PostgreSQL connection pool.
///
/// Configuration is read from environment variables:
///   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
class DatabaseConnection {
  static Pool? _pool;

  /// Returns the shared connection pool, creating it on first access.
  static Pool get pool {
    if (_pool != null) return _pool!;

    final host = _require('DB_HOST');
    final database = _require('DB_NAME');
    final username = _require('DB_USER');
    final password = _require('DB_PASSWORD');
    final port = int.parse(Platform.environment['DB_PORT'] ?? '5432');

    _pool = Pool.withEndpoints(
      [
        Endpoint(
          host: host,
          port: port,
          database: database,
          username: username,
          password: password,
        ),
      ],
      settings: const PoolSettings(maxConnectionCount: 10),
    );

    return _pool!;
  }

  /// Closes the pool and clears the singleton — primarily for tests.
  static Future<void> dispose() async {
    await _pool?.close();
    _pool = null;
  }

  static String _require(String key) {
    final value = Platform.environment[key];
    if (value == null || value.isEmpty) {
      throw StateError('Required environment variable $key is not set');
    }
    return value;
  }
}
