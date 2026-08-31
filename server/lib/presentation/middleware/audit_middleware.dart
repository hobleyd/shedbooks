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
  // Never log reads of the audit log or user list (read-only, potentially high-frequency).
  if (path.endsWith('/admin/audit-log')) return false;
  if (path.endsWith('/admin/users')) return false;
  // parse-import only parses a CSV in memory — no data is persisted.
  if (path.endsWith('/parse-import')) return false;
  // Reading O365 settings (e.g. on every visit to the admin screen) is not
  // a mutation; the PUT save below is still audited via the /admin/ rule.
  if (path.endsWith('/admin/o365-settings') && method == 'GET') return false;
  // CardDAV reads are high-frequency and produce no data mutations.
  if (path.startsWith('/carddav/') && method == 'PROPFIND') return false;
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
  if (path.endsWith('/aba-sequences/next')) return 'ABA_EXPORT';
  if (path.endsWith('/mark-paid')) return 'MARK_PAID';
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
  'aba-sequences': 'aba_sequences',
  'budgets': 'budgets',
  'members': 'members',
  'carddav': 'members',
  'assets': 'assets',
  'invoices': 'invoices',
  'api-key': 'user_api_keys',
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
    'merge', 'effective', 'backup', 'restore', 'audit-log', 'users', 'next',
    'confirm-import', 'gl-mappings', 'import', 'members',
    'next-number', 'mark-paid', 'generate', 'sync-o365',
    'generate-certificate', 'sections',
  };
  final last = parts.last;
  if (nonIdSegments.contains(last)) return null;
  return last.endsWith('.vcf') ? last.substring(0, last.length - 4) : last;
}
