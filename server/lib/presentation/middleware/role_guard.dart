import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../domain/enums/app_role.dart';

/// Extracts the authenticated user's role from the request context.
///
/// Roles are read from the `https://shedbooks.com/roles` JWT claim populated
/// by the Auth0 Action.  Defaults to [AppRole.viewer] when the claim is
/// absent so that no privilege is granted by omission.
AppRole roleFromRequest(Request request) {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  final raw = claims?['https://shedbooks.com/roles'];
  final roles = raw is List ? raw : <dynamic>[];
  return AppRole.fromClaims(roles);
}

/// Middleware that returns 403 if the caller is a [AppRole.contributor].
///
/// Used on routes that [AppRole.viewer] and [AppRole.administrator] may
/// access but [AppRole.contributor] may not (audit log, bank accounts,
/// GST rates, backup).
Middleware blockContributor() => _guard(
      (role) => role == AppRole.contributor,
    );

/// Middleware that returns 403 unless the caller is at least
/// [AppRole.contributor].
///
/// Used on write routes for general data resources (transactions, contacts,
/// general ledger, entity details).
Middleware requireContributor() => _guard(
      (role) => !role.atLeast(AppRole.contributor),
    );

/// Middleware that returns 403 unless the caller is [AppRole.administrator].
///
/// Used on routes that modify privileged resources (bank accounts, GST
/// rates, backup/restore).
Middleware requireAdministrator() => _guard(
      (role) => role != AppRole.administrator,
    );

// ── Private ────────────────────────────────────────────────────────────────

Middleware _guard(bool Function(AppRole) shouldReject) {
  return (Handler inner) => (Request request) {
        final role = roleFromRequest(request);
        if (shouldReject(role)) return _forbidden();
        return inner(request);
      };
}

Response _forbidden() => Response.forbidden(
      jsonEncode({'error': 'Insufficient permissions'}),
      headers: {'content-type': 'application/json'},
    );
