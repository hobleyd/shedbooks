import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../../infrastructure/encryption/backup_crypto.dart';

/// Handles entity-scoped backup and restore via HTTP.
///
/// Backup exports all rows belonging to the authenticated entity as a
/// structured JSON file. Restore deletes existing entity data and re-inserts
/// from the JSON file, wrapped in a single database transaction.
class BackupHandler {
  final Pool _pool;

  const BackupHandler({required Pool pool}) : _pool = pool;

  static const _jsonbColumns = {'selected_account_pairs', 'changes'};
  static const _defaultBackupKey = 'shedbooks-backup-default-key-v1';

  BackupCrypto get _crypto => BackupCrypto(
        Platform.environment['BACKUP_KEY'] ?? _defaultBackupKey,
      );

  /// GET /admin/backup
  ///
  /// Queries every table scoped to the authenticated entity and returns the
  /// result as a downloadable JSON attachment.
  Future<Response> handleBackup(Request request) async {
    if (!_isAuthenticated(request)) return _unauthorized();
    final entityId = _getEntityId(request);
    if (entityId == null) return _forbidden();

    try {
      final gl = await _queryRows('''
        SELECT id::text, entity_id, label, description, gst_applicable,
               direction::text AS direction, parent_id::text,
               created_at, updated_at, deleted_at
        FROM general_ledger WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final gstRates = await _queryRows('''
        SELECT id::text, entity_id, rate::text, effective_from,
               created_at, updated_at, deleted_at
        FROM gst_rates WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final contacts = await _queryRows('''
        SELECT id::text, entity_id, name,
               contact_type::text AS contact_type,
               gst_registered, abn, bsb, account_number,
               created_at, updated_at, deleted_at
        FROM contacts WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final transactions = await _queryRows('''
        SELECT id::text, entity_id, contact_id::text, general_ledger_id::text,
               amount, gst_amount,
               transaction_type::text AS transaction_type,
               receipt_number, description, transaction_date, is_cash,
               created_at, updated_at, deleted_at, bank_matched
        FROM transactions WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final bankAccounts = await _queryRows('''
        SELECT id::text, entity_id, bank_name, account_name, bsb,
               account_number, account_type, currency, is_system, sort_order,
               created_at, updated_at, deleted_at
        FROM bank_accounts WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final closingBalances = await _queryRows('''
        SELECT id::text, entity_id, bank_account_id::text, balance_date,
               balance_cents, statement_period, created_at
        FROM closing_bank_balances WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final lockedMonths = await _queryRows('''
        SELECT id::text, entity_id, month_year, locked_at, bank_account_id::text
        FROM locked_months WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final bankImports = await _queryRows('''
        SELECT id::text, entity_id, process_date, description,
               amount_cents, is_debit, imported_at
        FROM bank_imports WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final dashPrefs = await _queryRows(
        'SELECT entity_id, selected_gl_ids, selected_account_pairs '
        'FROM dashboard_preferences WHERE entity_id = @entityId',
        {'entityId': entityId},
      );

      final entityDetails = await _queryRows(
        'SELECT entity_id, name, abn, incorporation_identifier, '
        'money_in_receipt_format, money_out_receipt_format, apca_id, '
        'created_at, updated_at FROM entity_details WHERE entity_id = @entityId',
        {'entityId': entityId},
      );

      final auditLog = await _queryRows('''
        SELECT id::text, entity_id, user_id, user_email, ip_address,
               method, path, action, table_name, record_id,
               status_code, changes, created_at
        FROM audit_log WHERE entity_id = @entityId
        ORDER BY created_at
      ''', {'entityId': entityId});

      final budgets = await _queryRows('''
        SELECT id::text, entity_id, year, created_at, updated_at
        FROM budgets WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final budgetLines = await _queryRows('''
        SELECT bl.id::text, bl.budget_id::text, bl.general_ledger_id::text,
               bl.month, bl.amount_cents
        FROM budget_lines bl
        JOIN budgets b ON b.id = bl.budget_id
        WHERE b.entity_id = @entityId
      ''', {'entityId': entityId});

      final budgetGlMappings = await _queryRows('''
        SELECT id::text, entity_id, external_code, external_name,
               general_ledger_id::text
        FROM budget_gl_mappings WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final backup = <String, dynamic>{
        'version': 1,
        'entity_id': entityId,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'general_ledger': gl,
        'gst_rates': gstRates,
        'contacts': contacts,
        'transactions': transactions,
        'bank_accounts': bankAccounts,
        'closing_bank_balances': closingBalances,
        'locked_months': lockedMonths,
        'bank_imports': bankImports,
        'dashboard_preferences': dashPrefs,
        'entity_details': entityDetails,
        'audit_log': auditLog,
        'budgets': budgets,
        'budget_lines': budgetLines,
        'budget_gl_mappings': budgetGlMappings,
      };

      final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(backup)));
      final bytes = _crypto.encryptAndCompress(jsonBytes);
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition':
              'attachment; filename="shedbooks-backup-$stamp.bak"',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Backup failed: $e'}),
        headers: _jsonHeaders,
      );
    }
  }

  /// POST /admin/restore
  ///
  /// Accepts a JSON backup produced by [handleBackup]. Validates that the
  /// backup's entity_id matches the authenticated user, then within a single
  /// transaction deletes all existing entity data and re-inserts from the
  /// backup.
  Future<Response> handleRestore(Request request) async {
    if (!_isAuthenticated(request)) return _unauthorized();
    final entityId = _getEntityId(request);
    if (entityId == null) return _forbidden();

    final rawBytes =
        Uint8List.fromList(await request.read().expand((c) => c).toList());

    final Map<String, dynamic> backup;
    try {
      final Uint8List jsonBytes;
      if (BackupCrypto.isEncrypted(rawBytes)) {
        jsonBytes = _crypto.decryptAndDecompress(rawBytes);
      } else {
        // Legacy plain-JSON backup (.json files from before encryption).
        jsonBytes = rawBytes;
      }
      backup = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    } catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid backup file: $e'}),
        headers: _jsonHeaders,
      );
    }

    if ((backup['version'] as int?) != 1) {
      return Response(
        400,
        body: jsonEncode({'error': 'Unsupported backup version'}),
        headers: _jsonHeaders,
      );
    }

    if ((backup['entity_id'] as String?) != entityId) {
      return Response(
        403,
        body: jsonEncode(
            {'error': 'Backup belongs to a different entity'}),
        headers: _jsonHeaders,
      );
    }

    try {
      await _pool.runTx((tx) async {
        // ── Delete existing entity data in reverse FK order ────────────────
        await _del(tx, 'audit_log', entityId);
        await _del(tx, 'budget_gl_mappings', entityId);
        await _del(tx, 'budgets', entityId); // cascades to budget_lines
        await _del(tx, 'transactions', entityId);
        await _del(tx, 'contacts', entityId);
        await _del(tx, 'general_ledger', entityId);
        await _del(tx, 'gst_rates', entityId);
        await _del(tx, 'closing_bank_balances', entityId);
        await _del(tx, 'locked_months', entityId);
        await _del(tx, 'bank_imports', entityId);
        await _del(tx, 'bank_accounts', entityId);
        await tx.execute(
          Sql.named('DELETE FROM dashboard_preferences WHERE entity_id = @e'),
          parameters: {'e': entityId},
        );
        await tx.execute(
          Sql.named('DELETE FROM entity_details WHERE entity_id = @e'),
          parameters: {'e': entityId},
        );

        // ── Re-insert in FK dependency order ──────────────────────────────

        for (final r in _rows(backup, 'entity_details')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO entity_details
                (entity_id, name, abn, incorporation_identifier,
                 money_in_receipt_format, money_out_receipt_format, apca_id,
                 created_at, updated_at)
              VALUES (
                @e, @name, @abn, @inc,
                @mir, @mor, @apca,
                @ca::timestamptz, @ua::timestamptz
              )
            '''),
            parameters: {
              'e': entityId,
              'name': r['name'] as String,
              'abn': r['abn'] as String,
              'inc': r['incorporation_identifier'] as String,
              'mir': (r['money_in_receipt_format'] as String?) ?? '',
              'mor': (r['money_out_receipt_format'] as String?) ?? '',
              'apca': r['apca_id'],
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
            },
          );
        }

        for (final r in _rows(backup, 'dashboard_preferences')) {
          final glIds = r['selected_gl_ids'];
          final glIdsJson = glIds is String ? glIds : jsonEncode(glIds ?? []);
          final pairs = r['selected_account_pairs'];
          final pairsJson =
              pairs is String ? pairs : jsonEncode(pairs ?? []);
          await tx.execute(
            Sql.named('''
              INSERT INTO dashboard_preferences
                (entity_id, selected_gl_ids, selected_account_pairs)
              VALUES (
                @e,
                ARRAY(SELECT jsonb_array_elements_text(@glIds::jsonb)),
                @pairs::jsonb
              )
            '''),
            parameters: {
              'e': entityId,
              'glIds': glIdsJson,
              'pairs': pairsJson,
            },
          );
        }

        for (final r in _rows(backup, 'bank_accounts')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO bank_accounts
                (id, entity_id, bank_name, account_name, bsb, account_number,
                 account_type, currency, is_system, sort_order,
                 created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @bn, @an, @bsb, @anum,
                @at, @cur, @sys, @so,
                @ca::timestamptz, @ua::timestamptz, @da::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'bn': r['bank_name'] as String,
              'an': r['account_name'] as String,
              'bsb': r['bsb'] as String,
              'anum': r['account_number'] as String,
              'at': r['account_type'] as String,
              'cur': r['currency'] as String,
              'sys': (r['is_system'] as bool?) ?? false,
              'so': (r['sort_order'] as int?) ?? 0,
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
              'da': r['deleted_at'],
            },
          );
        }

        for (final r in _rows(backup, 'gst_rates')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO gst_rates
                (id, entity_id, rate, effective_from, created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @rate::numeric,
                @ef::date,
                @ca::timestamptz, @ua::timestamptz, @da::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'rate': r['rate'] as String,
              'ef': _dateString(r['effective_from']),
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
              'da': r['deleted_at'],
            },
          );
        }

        // Insert all GL rows with parent_id = NULL first (self-referencing FK
        // requires parents to exist before children can reference them).
        final glRows = _rows(backup, 'general_ledger');
        for (final r in glRows) {
          await tx.execute(
            Sql.named('''
              INSERT INTO general_ledger
                (id, entity_id, label, description, gst_applicable,
                 direction, created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @lbl, @desc, @gst,
                @dir::gl_direction,
                @ca::timestamptz, @ua::timestamptz, @da::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'lbl': r['label'] as String,
              'desc': r['description'] as String,
              'gst': r['gst_applicable'] as bool,
              'dir': r['direction'] as String,
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
              'da': r['deleted_at'],
            },
          );
        }
        // Second pass: restore parent_id now that all rows exist.
        for (final r in glRows) {
          final parentId = r['parent_id'] as String?;
          if (parentId == null) continue;
          await tx.execute(
            Sql.named('''
              UPDATE general_ledger
              SET parent_id = @pid::uuid
              WHERE id = @id::uuid AND entity_id = @e
            '''),
            parameters: {
              'pid': parentId,
              'id': r['id'] as String,
              'e': entityId,
            },
          );
        }

        for (final r in _rows(backup, 'contacts')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO contacts
                (id, entity_id, name, contact_type, gst_registered, abn,
                 bsb, account_number, created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @name, @ct::contact_type, @gst, @abn,
                @bsb, @anum,
                @ca::timestamptz, @ua::timestamptz, @da::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'name': r['name'] as String,
              'ct': r['contact_type'] as String,
              'gst': r['gst_registered'] as bool,
              'abn': r['abn'],
              'bsb': r['bsb'],
              'anum': r['account_number'],
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
              'da': r['deleted_at'],
            },
          );
        }

        for (final r in _rows(backup, 'transactions')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO transactions
                (id, entity_id, contact_id, general_ledger_id, amount,
                 gst_amount, transaction_type, receipt_number, description,
                 transaction_date, is_cash, created_at, updated_at, deleted_at,
                 bank_matched)
              VALUES (
                @id::uuid, @e, @cid::uuid, @glid::uuid,
                @amt, @gst, @tt::transaction_type,
                @rcpt, @desc, @td::date, @ic,
                @ca::timestamptz, @ua::timestamptz, @da::timestamptz, @bm
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'cid': r['contact_id'] as String,
              'glid': r['general_ledger_id'] as String,
              'amt': r['amount'] as int,
              'gst': r['gst_amount'] as int,
              'tt': r['transaction_type'] as String,
              'rcpt': r['receipt_number'] as String,
              'desc': r['description'] as String,
              'td': _dateString(r['transaction_date']),
              'ic': (r['is_cash'] as bool?) ?? false,
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
              'da': r['deleted_at'],
              'bm': (r['bank_matched'] as bool?) ?? false,
            },
          );
        }

        for (final r in _rows(backup, 'closing_bank_balances')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO closing_bank_balances
                (id, entity_id, bank_account_id, balance_date,
                 balance_cents, statement_period, created_at)
              VALUES (
                @id::uuid, @e, @baid::uuid, @bd::date,
                @bc, @sp, @ca::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'baid': r['bank_account_id'] as String,
              'bd': _dateString(r['balance_date']),
              'bc': r['balance_cents'] as int,
              'sp': r['statement_period'] as String,
              'ca': r['created_at'] as String,
            },
          );
        }

        for (final r in _rows(backup, 'locked_months')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO locked_months
                (id, entity_id, month_year, locked_at, bank_account_id)
              VALUES (
                @id::uuid, @e, @my, @la::timestamptz, @baid::uuid
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'my': r['month_year'] as String,
              'la': r['locked_at'] as String,
              'baid': r['bank_account_id'] as String,
            },
          );
        }

        for (final r in _rows(backup, 'bank_imports')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO bank_imports
                (id, entity_id, process_date, description,
                 amount_cents, is_debit, imported_at)
              VALUES (
                @id::uuid, @e, @pd::date, @desc,
                @ac, @dbt, @ia::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'pd': _dateString(r['process_date']),
              'desc': r['description'] as String,
              'ac': r['amount_cents'] as int,
              'dbt': r['is_debit'] as bool,
              'ia': r['imported_at'] as String,
            },
          );
        }

        for (final r in _rows(backup, 'audit_log')) {
          final changes = r['changes'];
          final changesJson =
              changes == null ? null : (changes is String ? changes : jsonEncode(changes));
          await tx.execute(
            Sql.named('''
              INSERT INTO audit_log
                (id, entity_id, user_id, user_email, ip_address,
                 method, path, action, table_name, record_id,
                 status_code, changes, created_at)
              VALUES (
                @id::uuid, @e, @uid, @ue, @ip,
                @meth, @path, @act, @tbl, @rid,
                @sc, @chg::jsonb, @ca::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'uid': r['user_id'] as String,
              'ue': r['user_email'] as String,
              'ip': r['ip_address'] as String,
              'meth': r['method'] as String,
              'path': r['path'] as String,
              'act': r['action'] as String,
              'tbl': r['table_name'] as String,
              'rid': r['record_id'],
              'sc': r['status_code'] as int,
              'chg': changesJson,
              'ca': r['created_at'] as String,
            },
          );
        }

        for (final r in _rows(backup, 'budgets')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO budgets (id, entity_id, year, created_at, updated_at)
              VALUES (
                @id::uuid, @e, @yr,
                @ca::timestamptz, @ua::timestamptz
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'yr': r['year'] as int,
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
            },
          );
        }

        for (final r in _rows(backup, 'budget_lines')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO budget_lines
                (id, budget_id, general_ledger_id, month, amount_cents)
              VALUES (
                @id::uuid, @bid::uuid, @glid::uuid, @month, @cents
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'bid': r['budget_id'] as String,
              'glid': r['general_ledger_id'] as String,
              'month': r['month'] as int,
              'cents': r['amount_cents'] as int,
            },
          );
        }

        for (final r in _rows(backup, 'budget_gl_mappings')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO budget_gl_mappings
                (id, entity_id, external_code, external_name, general_ledger_id)
              VALUES (
                @id::uuid, @e, @code, @name, @glid::uuid
              )
            '''),
            parameters: {
              'id': r['id'] as String,
              'e': entityId,
              'code': r['external_code'] as String,
              'name': (r['external_name'] as String?) ?? '',
              'glid': r['general_ledger_id'] as String,
            },
          );
        }
      });

      return Response.ok(
        jsonEncode({'message': 'Restore completed successfully'}),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Restore failed: $e'}),
        headers: _jsonHeaders,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _queryRows(
    String sql,
    Map<String, dynamic> params,
  ) async {
    final result = await _pool.execute(Sql.named(sql), parameters: params);
    return result.map((row) => _serialize(row.toColumnMap())).toList();
  }

  static Future<void> _del(TxSession tx, String table, String entityId) =>
      tx.execute(
        Sql.named('DELETE FROM $table WHERE entity_id = @e'),
        parameters: {'e': entityId},
      );

  static Map<String, dynamic> _serialize(Map<String, dynamic> row) {
    return row.map((key, value) {
      if (value is DateTime) return MapEntry(key, value.toIso8601String());
      // JSONB can arrive as a decoded Dart object or a raw JSON string.
      // Decode strings for known JSONB columns so they serialize cleanly.
      if (value is String && _jsonbColumns.contains(key)) {
        try {
          return MapEntry(key, jsonDecode(value));
        } catch (_) {}
      }
      return MapEntry(key, value);
    });
  }

  static List<Map<String, dynamic>> _rows(
          Map<String, dynamic> backup, String table) =>
      ((backup[table] as List?) ?? []).cast<Map<String, dynamic>>();

  /// Returns the date portion of a value that may be an ISO timestamp string
  /// or a DateTime (as serialized by [_serialize]).
  static String _dateString(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  static bool _isAuthenticated(Request request) =>
      request.context['auth.claims'] != null;

  static String? _getEntityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static Response _unauthorized() => Response.unauthorized(
        jsonEncode({'error': 'Authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _forbidden() => Response.forbidden(
        jsonEncode({'error': 'No entity ID in token'}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
