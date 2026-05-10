import 'dart:async';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../../domain/entities/audit_entry.dart';
import '../../infrastructure/repositories/postgres_audit_repository.dart';

/// Shelf middleware that writes an [AuditEntry] after every auditable request.
///
/// Must be placed **after** the auth middleware in the pipeline so that
/// `request.context['auth.claims']` is populated.
///
/// Audit inserts are fire-and-forget — a logging failure never affects the
/// HTTP response returned to the client.
Middleware auditMiddleware(Pool pool) {
  final repo = PostgresAuditRepository(pool);

  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);

      final method = request.method.toUpperCase();
      final path = request.requestedUri.path;

      if (_shouldAudit(method, path, response.statusCode)) {
        unawaited(
          _record(repo, request, method, path, response.statusCode)
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
) async {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  final entityId =
      claims?['https://shedbooks.com/entity_id'] as String? ?? '';
  final userId = claims?['sub'] as String? ?? '';
  final userEmail = claims?['email'] as String? ?? '';

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
    createdAt: DateTime.now(),
  ));
}

String _extractIp(Request request) {
  final xff = request.headers['x-forwarded-for'];
  if (xff != null && xff.isNotEmpty) return xff.split(',').first.trim();
  return request.headers['x-real-ip'] ?? '';
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
