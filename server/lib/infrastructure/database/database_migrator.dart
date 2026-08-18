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
import 'package:postgres/postgres.dart';

/// Applies pending SQL migrations at application startup.
///
/// Migration files are plain .sql files discovered in [migrationsDir] and
/// applied in lexicographic order. Applied versions are tracked in the
/// [schema_migrations] table.
///
/// For databases that were initialised via docker-entrypoint-initdb.d before
/// this system existed, the known legacy versions are seeded into
/// [schema_migrations] automatically (detected by the presence of the
/// general_ledger table with an empty schema_migrations table), so they are
/// never re-executed.
class DatabaseMigrator {
  final Pool _pool;
  final String _migrationsDir;

  static final _log = Logger('DatabaseMigrator');

  /// Versions that were applied via docker-entrypoint-initdb.d before the
  /// automated migration runner was introduced.
  static const _legacyVersions = [
    '001_create_general_ledger',
    '002_create_gst_rates',
    '003_create_contacts',
    '004_create_transactions',
    '005_add_entity_id',
    '006_add_gl_direction',
    '007_add_dashboard_preferences',
    '008_add_entity_details',
    '009_add_bank_accounts',
    '010_add_abn_to_contacts',
    '011_add_description_to_transactions',
    '012_add_selected_account_pairs',
  ];

  /// Reads [MIGRATIONS_DIR] from the environment, falling back to the
  /// source-relative path used during local development.
  DatabaseMigrator(this._pool, {String? migrationsDir})
      : _migrationsDir = migrationsDir ??
            Platform.environment['MIGRATIONS_DIR'] ??
            'lib/infrastructure/database/migrations';

  /// A fixed, arbitrary key for a session-scoped Postgres advisory lock —
  /// any bigint works as long as it's not reused elsewhere in the app.
  static const _migrationLockKey = 727142;

  /// Discovers and applies all pending migrations, then returns.
  ///
  /// Holds a Postgres advisory lock for the duration so that two server
  /// instances starting concurrently (e.g. overlapping Container Apps
  /// revisions during a rolling deploy) don't both try to apply the same
  /// migration at once — the second instance blocks here until the first
  /// finishes, rather than racing on the same DDL. The lock is released
  /// automatically if the holding connection drops.
  ///
  /// Throws if any migration fails — the caller should abort server startup.
  Future<void> migrate() async {
    await _pool.withConnection((lockConnection) async {
      await lockConnection.execute('SELECT pg_advisory_lock($_migrationLockKey)');
      try {
        await _migrateLocked();
      } finally {
        await lockConnection.execute('SELECT pg_advisory_unlock($_migrationLockKey)');
      }
    });
  }

  Future<void> _migrateLocked() async {
    _log.info('Running database migrations from $_migrationsDir');

    await _ensureTrackingTable();

    final applied = await _loadAppliedVersions();

    if (applied.isEmpty) {
      await _seedLegacyVersionsIfExistingDatabase(applied);
    }

    final files = _migrationFiles();
    var count = 0;

    for (final file in files) {
      final version = _versionOf(file);
      if (applied.contains(version)) continue;

      _log.info('Applying: $version');
      await _pool.runTx((tx) async {
        await _runStatements(tx, File(file).readAsStringSync());
        await tx.execute(
          Sql.named(
            'INSERT INTO schema_migrations (version) VALUES (@v)',
          ),
          parameters: {'v': version},
        );
      });
      _log.info('Applied:  $version');
      count++;
    }

    _log.info(count == 0 ? 'No pending migrations.' : '$count migration(s) applied.');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _ensureTrackingTable() async {
    await _pool.execute(
      'CREATE TABLE IF NOT EXISTS schema_migrations ('
      '  version    TEXT        PRIMARY KEY, '
      '  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()'
      ')',
    );
  }

  Future<Set<String>> _loadAppliedVersions() async {
    final result = await _pool.execute(
      'SELECT version FROM schema_migrations ORDER BY version',
    );
    return result.map((r) => r.toColumnMap()['version'] as String).toSet();
  }

  /// If schema_migrations is empty but the general_ledger table already
  /// exists, the database was previously bootstrapped via
  /// docker-entrypoint-initdb.d.  Seed the known legacy versions so the
  /// runner does not attempt to re-apply them.
  Future<void> _seedLegacyVersionsIfExistingDatabase(
    Set<String> applied,
  ) async {
    final result = await _pool.execute(
      "SELECT EXISTS("
      "  SELECT 1 FROM information_schema.tables "
      "  WHERE table_schema = 'public' AND table_name = 'general_ledger'"
      ") AS is_existing",
    );
    final isExisting = result.first.toColumnMap()['is_existing'] as bool;
    if (!isExisting) return;

    _log.info(
      'Existing database detected — seeding ${_legacyVersions.length} '
      'legacy migration version(s) into schema_migrations.',
    );
    for (final version in _legacyVersions) {
      await _pool.execute(
        Sql.named(
          'INSERT INTO schema_migrations (version) VALUES (@v) '
          'ON CONFLICT DO NOTHING',
        ),
        parameters: {'v': version},
      );
      applied.add(version);
    }
  }

  List<String> _migrationFiles() {
    final dir = Directory(_migrationsDir);
    if (!dir.existsSync()) {
      _log.warning('Migrations directory not found: $_migrationsDir');
      return [];
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .map((f) => f.path)
        .toList()
      ..sort();
    return files;
  }

  /// Derives the migration version from a file path — the filename minus
  /// the .sql extension.
  static String _versionOf(String filePath) =>
      Uri.file(filePath).pathSegments.last.replaceAll('.sql', '');

  /// Strips single-line comments then splits [sql] into individual statements
  /// on `;` and executes each in order.  Comments are removed first so that
  /// semicolons inside comments do not produce spurious empty statements.
  static Future<void> _runStatements(TxSession tx, String sql) async {
    final stripped = sql.replaceAll(RegExp(r'--[^\n]*'), '');
    final statements = stripped
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final stmt in statements) {
      await tx.execute(stmt);
    }
  }
}
