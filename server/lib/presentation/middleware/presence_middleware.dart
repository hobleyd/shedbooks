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

import '../../domain/entities/user_presence.dart';
import '../../domain/enums/app_role.dart';
import '../../infrastructure/repositories/postgres_user_presence_repository.dart';

/// Shelf middleware that upserts a [UserPresence] record after every
/// successful authenticated request.
///
/// Must be placed **after** the auth middleware in the pipeline so that
/// `request.context['auth.claims']` is populated.
///
/// Upserts are fire-and-forget and never block the HTTP response.
Middleware presenceMiddleware(Pool pool) {
  final repo = PostgresUserPresenceRepository(pool);

  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final claims = request.context['auth.claims'] as Map<String, dynamic>?;
        if (claims != null) {
          final entityId =
              claims['https://shedbooks.com/entity_id'] as String? ?? '';
          final userId = claims['sub'] as String? ?? '';
          if (entityId.isNotEmpty && userId.isNotEmpty) {
            unawaited(_upsert(repo, claims, request).catchError((_) {}));
          }
        }
      }

      return response;
    };
  };
}

Future<void> _upsert(
  PostgresUserPresenceRepository repo,
  Map<String, dynamic> claims,
  Request request,
) async {
  final entityId =
      claims['https://shedbooks.com/entity_id'] as String? ?? '';
  final userId = claims['sub'] as String? ?? '';
  final userEmail = (claims['email'] as String?)?.isNotEmpty == true
      ? claims['email'] as String
      : (claims['https://shedbooks.com/email'] as String?) ?? '';

  final raw = claims['https://shedbooks.com/roles'];
  final roles = raw is List ? raw : <dynamic>[];
  final role = AppRole.fromClaims(roles).name;

  await repo.upsert(UserPresence(
    entityId: entityId,
    userId: userId,
    userEmail: userEmail,
    role: role,
    lastSeen: DateTime.now(),
    ipAddress: _extractIp(request),
  ));
}

String _extractIp(Request request) {
  final cf = request.headers['cf-connecting-ip'];
  if (cf != null && cf.isNotEmpty) return cf.trim();
  final realIp = request.headers['x-real-ip'];
  if (realIp != null && realIp.isNotEmpty) return realIp.trim();
  final xff = request.headers['x-forwarded-for'];
  if (xff != null && xff.isNotEmpty) return xff.split(',').first.trim();
  return '';
}
