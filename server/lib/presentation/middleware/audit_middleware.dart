import 'dart:async';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../../domain/entities/audit_entry.dart';
import '../../infrastructure/repositories/postgres_audit_repository.dart';
import '../audit_changes.dart';

/// Shelf middleware that writes an [AuditEntry] after every auditable request.
///
/// Must be placed **after** the auth middleware in the pipeline so that
/// `request.context['auth.claims']` is populated.
///
/// An [AuditChanges] instance is injected into the request context under the
/// key `'audit.changes'` before the inner handler runs.  Handlers may call
/// `AuditChanges.set()` to attach field-level change details.
///
/// Audit inserts are fire-and-forget — a logging failure never affects the
/// HTTP response returned to the client.
Middleware auditMiddleware(Pool pool) {
  final repo = PostgresAuditRepository(pool);

  return (Handler inner) {
    return (Request request) async {
      final changes = AuditChanges();
      final augmented = request.change(
        context: {...request.context, 'audit.changes': changes},
      );

      final response = await inner(augmented);

      final method = request.method.toUpperCase();
      final path = request.requestedUri.path;

      if (_shouldAudit(method, path, response.statusCode)) {
        unawaited(
          _record(repo, augmented, method, path, response.statusCode, changes.data)
              .catchError((_) {}),
        );
      }

      return response;
    };
  };
}

// ── Private helpers ────────────────────────────────────────────────────────

bool _shouldAudit(String method, String path, int statusCode) {
  if (statusCode < 200 || statusCode >= 300) return false;
  // Never log reads of the audit log itself.
  if (path.endsWith('/admin/audit-log')) return false;
  // Always audit admin operations (backup/restore are sensitive reads/writes).
  if (path.contains('/admin/')) return true;
  // Audit all mutating requests on data resources.
  return const {'POST', 'PUT', 'DELETE', 'PATCH'}.contains(method);
}

Future<void> _record(
  PostgresAuditRepository repo,
  Request request,
  String method,
  String path,
  int statusCode,
  Map<String, dynamic>? changes,
) async {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  final entityId =
      claims?['https://shedbooks.com/entity_id'] as String? ?? '';
  final userId = claims?['sub'] as String? ?? '';
  // email may be a plain claim or namespaced — accept both.
  final userEmail = (claims?['email'] as String?)?.isNotEmpty == true
      ? claims!['email'] as String
      : (claims?['https://shedbooks.com/email'] as String?) ?? '';

  await repo.insert(AuditEntry(
    id: '',
    entityId: entityId,
    userId: userId,
    userEmail: userEmail,
    ipAddress: _extractIp(request),
    method: method,
    path: path,
    action: _action(method, path),
    tableName: _tableName(path),
    recordId: _recordId(path),
    statusCode: statusCode,
    changes: changes,
    createdAt: DateTime.now(),
  ));
}

String _extractIp(Request request) {
  // Cloudflare sets this to the real client IP before any XFF manipulation.
  final cf = request.headers['cf-connecting-ip'];
  if (cf != null && cf.isNotEmpty) return cf.trim();
  // X-Real-IP is set by nginx after the real_ip module has resolved the
  // genuine client address from the XFF chain.
  final realIp = request.headers['x-real-ip'];
  if (realIp != null && realIp.isNotEmpty) return realIp.trim();
  // Last resort: first entry in X-Forwarded-For.
  final xff = request.headers['x-forwarded-for'];
  if (xff != null && xff.isNotEmpty) return xff.split(',').first.trim();
  return '';
}

String _action(String method, String path) {
  if (path.endsWith('/backup')) return 'BACKUP';
  if (path.endsWith('/restore')) return 'RESTORE';
  if (path.endsWith('/merge')) return 'MERGE';
  return switch (method) {
    'POST' => 'CREATE',
    'PUT' => 'UPDATE',
    'DELETE' => 'DELETE',
    'PATCH' => 'UPDATE',
    _ => method,
  };
}

const _tableMap = {
  'contacts': 'contacts',
  'general-ledger': 'general_ledger',
  'transactions': 'transactions',
  'gst-rates': 'gst_rates',
  'bank-accounts': 'bank_accounts',
  'entity-details': 'entity_details',
  'dashboard-preferences': 'dashboard_preferences',
  'abn-lookup': 'contacts',
};

String _tableName(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.first == 'admin') {
    return parts.length > 1 ? 'admin.${parts[1]}' : 'admin';
  }
  return _tableMap[parts.first] ?? parts.first;
}

String? _recordId(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return null;
  const nonIdSegments = {
    'merge', 'effective', 'backup', 'restore', 'audit-log',
  };
  final last = parts.last;
  if (nonIdSegments.contains(last)) return null;
  return last;
}
