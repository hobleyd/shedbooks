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
