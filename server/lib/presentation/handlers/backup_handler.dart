import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

/// Handles entity-scoped backup and restore via HTTP.
///
/// Backup exports all rows belonging to the authenticated entity as a
/// structured JSON file. Restore deletes existing entity data and re-inserts
/// from the JSON file, wrapped in a single database transaction.
class BackupHandler {
  final Pool _pool;

  const BackupHandler({required Pool pool}) : _pool = pool;

  static const _jsonbColumns = {'selected_account_pairs'};

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
               direction::text AS direction, created_at, updated_at, deleted_at
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
               gst_registered, abn, created_at, updated_at, deleted_at
        FROM contacts WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final transactions = await _queryRows('''
        SELECT id::text, entity_id, contact_id::text, general_ledger_id::text,
               amount, gst_amount,
               transaction_type::text AS transaction_type,
               receipt_number, description, transaction_date,
               created_at, updated_at, deleted_at
        FROM transactions WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final bankAccounts = await _queryRows('''
        SELECT id::text, entity_id, bank_name, account_name, bsb,
               account_number, account_type, currency,
               created_at, updated_at, deleted_at
        FROM bank_accounts WHERE entity_id = @entityId
      ''', {'entityId': entityId});

      final dashPrefs = await _queryRows(
        'SELECT entity_id, selected_gl_ids, selected_account_pairs '
        'FROM dashboard_preferences WHERE entity_id = @entityId',
        {'entityId': entityId},
      );

      final entityDetails = await _queryRows(
        'SELECT entity_id, name, abn, incorporation_identifier, '
        'created_at, updated_at FROM entity_details WHERE entity_id = @entityId',
        {'entityId': entityId},
      );

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
        'dashboard_preferences': dashPrefs,
        'entity_details': entityDetails,
      };

      final bytes = utf8.encode(jsonEncode(backup));
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition':
              'attachment; filename="shedbooks-backup-$stamp.json"',
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

    final bodyBytes =
        await request.read().expand((chunk) => chunk).toList();

    final Map<String, dynamic> backup;
    try {
      backup = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid JSON: $e'}),
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
        await _del(tx, 'transactions', entityId);
        await _del(tx, 'contacts', entityId);
        await _del(tx, 'general_ledger', entityId);
        await _del(tx, 'gst_rates', entityId);
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
                (entity_id, name, abn, incorporation_identifier, created_at, updated_at)
              VALUES (@e, @name, @abn, @inc, @ca::timestamptz, @ua::timestamptz)
            '''),
            parameters: {
              'e': entityId,
              'name': r['name'] as String,
              'abn': r['abn'] as String,
              'inc': r['incorporation_identifier'] as String,
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
                 account_type, currency, created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @bn, @an, @bsb, @anum,
                @at, @cur,
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

        for (final r in _rows(backup, 'general_ledger')) {
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

        for (final r in _rows(backup, 'contacts')) {
          await tx.execute(
            Sql.named('''
              INSERT INTO contacts
                (id, entity_id, name, contact_type, gst_registered, abn,
                 created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @name, @ct::contact_type, @gst, @abn,
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
                 transaction_date, created_at, updated_at, deleted_at)
              VALUES (
                @id::uuid, @e, @cid::uuid, @glid::uuid,
                @amt, @gst, @tt::transaction_type,
                @rcpt, @desc, @td::date,
                @ca::timestamptz, @ua::timestamptz, @da::timestamptz
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
              'ca': r['created_at'] as String,
              'ua': r['updated_at'] as String,
              'da': r['deleted_at'],
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
