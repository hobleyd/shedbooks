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

import 'package:shelf/shelf.dart';

// Single source of truth for reading identity fields off the decoded JWT
// claims attached to `request.context['auth.claims']` by the auth
// middleware. Every auth issuer (Auth0 today, Entra ID once added) is
// normalised to the same claim keys before it reaches here, so this file
// is the only place that needs to know those key names.

/// The authenticated caller's entity (tenant) id, or null if absent.
String? resolveEntityId(Request request) {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  return claims?['https://shedbooks.com/entity_id'] as String?;
}

/// The authenticated caller's subject id ('sub' claim), or null if absent.
String? resolveUserId(Request request) {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  return claims?['sub'] as String?;
}

/// The authenticated caller's email.
///
/// Reads the plain `email` claim, falling back to the namespaced
/// `https://shedbooks.com/email` claim. Defaults to '' (never null) since
/// every call site today wants an empty string rather than a null check.
String resolveEmail(Request request) {
  final claims = request.context['auth.claims'] as Map<String, dynamic>?;
  return (claims?['email'] as String?)?.isNotEmpty == true
      ? claims!['email'] as String
      : (claims?['https://shedbooks.com/email'] as String?) ?? '';
}
