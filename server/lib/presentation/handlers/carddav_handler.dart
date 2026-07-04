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

import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../application/member/create_member_use_case.dart';
import '../../application/member/delete_member_use_case.dart';
import '../../application/member/get_member_use_case.dart';
import '../../application/member/list_members_use_case.dart';
import '../../application/member/update_member_use_case.dart';
import '../../domain/entities/member.dart';
import '../../domain/exceptions/member_exception.dart';
import '../audit_changes.dart';
import 'handler_diff.dart';

/// Shelf handlers implementing the CardDAV addressbook protocol (RFC 6352).
///
/// Mounts at `/carddav/members/` and serves the entity-scoped membership
/// roster as a CardDAV addressbook collection.
///
/// Authentication accepts either:
/// - `Authorization: Bearer <jwt>` (standard API usage), or
/// - `Authorization: Basic base64(username:<jwt>)` (for CardDAV clients such
///   as iOS Contacts that require HTTP Basic Auth; the JWT is the password).
///
/// Supported operations:
/// - `OPTIONS`   → advertises DAV capabilities
/// - `PROPFIND`  → lists all vCards with their ETags (Depth: 0 or 1)
/// - `GET`       → returns a single member as a vCard 3.0 string
/// - `PUT`       → creates or updates a member from a vCard 3.0 body
/// - `DELETE`    → soft-deletes a member
class CardDavHandler {
  final ListMembersUseCase _list;
  final GetMemberUseCase _get;
  final CreateMemberUseCase _create;
  final UpdateMemberUseCase _update;
  final DeleteMemberUseCase _delete;

  static const _vcardType = 'text/vcard;charset=utf-8';
  static const _xmlType = 'application/xml;charset=utf-8';
  final String _basePath;
  final String _principalPath;

  const CardDavHandler({
    required ListMembersUseCase list,
    required GetMemberUseCase get,
    required CreateMemberUseCase create,
    required UpdateMemberUseCase update,
    required DeleteMemberUseCase delete,
    String pathPrefix = '/api',
  })  : _list = list,
        _get = get,
        _create = create,
        _update = update,
        _delete = delete,
        _basePath = '$pathPrefix/carddav/members',
        _principalPath = '$pathPrefix/carddav/principal';

  // ── OPTIONS /carddav/members ──────────────────────────────────────────────

  /// Advertises CardDAV capabilities.
  Future<Response> handleOptions(Request request) async {
    return Response.ok('', headers: {
      'Allow': 'OPTIONS, PROPFIND, GET, PUT, DELETE',
      'DAV': '1, 2, 3, addressbook',
      'Content-Length': '0',
    });
  }

  // ── PROPFIND /carddav/principal ───────────────────────────────────────────

  /// Returns the CardDAV principal resource for the authenticated user.
  ///
  /// macOS and iOS CardDAV clients follow [current-user-principal] from the
  /// addressbook PROPFIND to this URL to discover [addressbook-home-set].
  Future<Response> handlePrincipalPropfind(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final xml = _buildPrincipalResponse();
    return Response(207, body: xml, headers: {'Content-Type': _xmlType});
  }

  // ── PROPFIND /carddav/members ─────────────────────────────────────────────

  /// Returns a WebDAV multi-status listing all members with their ETags.
  Future<Response> handlePropfind(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final members = await _list.execute(entityId: entityId);
    final xml = _buildMultistatus(members);
    return Response(207, body: xml, headers: {'Content-Type': _xmlType});
  }

  // ── GET /carddav/members/:uid.vcf ─────────────────────────────────────────

  /// Returns a single member as a vCard 3.0 string.
  Future<Response> handleGet(Request request, String uid) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final id = _stripVcf(uid);
    try {
      final member = await _get.execute(id, entityId: entityId);
      return Response.ok(
        _toVCard(member),
        headers: {
          'Content-Type': _vcardType,
          'ETag': '"${member.etag}"',
        },
      );
    } on MemberNotFoundException {
      return Response.notFound('Not found');
    }
  }

  // ── PUT /carddav/members/:uid.vcf ─────────────────────────────────────────

  /// Creates or updates a member from a vCard 3.0 body.
  Future<Response> handlePut(Request request, String uid) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final id = _stripVcf(uid);
    final body = await request.readAsString();
    final fields = _parseVCard(body);

    // N field: "LastName;FirstName;;;" — prefer N over FN for structured names.
    final lastName = fields['n-last'] ?? '';
    final firstName = fields['n-first'] ?? '';
    if (lastName.trim().isEmpty) {
      return Response(400, body: 'N (structured name) with last name is required');
    }

    // Try to update first; if not found (or id is not a valid UUID), create.
    final isUuid = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false)
        .hasMatch(id);
    try {
      if (!isUuid) throw MemberNotFoundException(id);
      final existing = await _get.execute(id, entityId: entityId);
      final member = await _update.execute(
        id: existing.id,
        entityId: entityId,
        firstName: firstName,
        lastName: lastName,
        dateJoined: _parseDate(fields['x-date-joined']),
        membershipStatus: fields['x-membership-status'],
        streetAddress: fields['adr-street'],
        poBox: fields['adr-pobox'],
        email: fields['email'],
        phone: fields['tel'],
        dateOfBirth: _parseDate(fields['bday']),
        emergencyContactName: fields['x-emergency-contact-name'],
        emergencyContactPhone: fields['x-emergency-contact-phone'],
        woodworkingInduction: _parseDate(fields['x-woodworking-induction']),
        metalworkingInduction: _parseDate(fields['x-metalworking-induction']),
        gymWaiver: _parseDate(fields['x-gym-waiver']),
      );
      final diff = diffMaps(_snapshot(existing), _snapshot(member));
      if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      return Response.ok('', headers: {'ETag': '"${member.etag}"'});
    } on MemberNotFoundException {
      // Honour the UID from the URL by pre-generating — not supported directly
      // in the use case so we create a new record. The UID in the vCard is
      // stored in the database id field only when it is a valid UUID; otherwise
      // a new UUID is generated by the repository.
      final member = await _create.execute(
        entityId: entityId,
        firstName: firstName,
        lastName: lastName,
        dateJoined: _parseDate(fields['x-date-joined']),
        membershipStatus: fields['x-membership-status'],
        streetAddress: fields['adr-street'],
        poBox: fields['adr-pobox'],
        email: fields['email'],
        phone: fields['tel'],
        dateOfBirth: _parseDate(fields['bday']),
        emergencyContactName: fields['x-emergency-contact-name'],
        emergencyContactPhone: fields['x-emergency-contact-phone'],
        woodworkingInduction: _parseDate(fields['x-woodworking-induction']),
        metalworkingInduction: _parseDate(fields['x-metalworking-induction']),
        gymWaiver: _parseDate(fields['x-gym-waiver']),
      );
      _auditChanges(request)?.set(_snapshot(member));
      return Response(201, body: '', headers: {'ETag': '"${member.etag}"'});
    } on MemberValidationException catch (e) {
      return Response(400, body: e.message);
    }
  }

  // ── DELETE /carddav/members/:uid.vcf ─────────────────────────────────────

  /// Soft-deletes a member.
  Future<Response> handleDelete(Request request, String uid) async {
    final entityId = _entityId(request);
    if (entityId == null) return _unauthorized();

    final id = _stripVcf(uid);

    Member? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) _auditChanges(request)?.set(_snapshot(before));
      return Response(204);
    } on MemberNotFoundException {
      return Response.notFound('Not found');
    }
  }

  // ── vCard serialisation ───────────────────────────────────────────────────

  String _toVCard(Member m) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCARD');
    buf.writeln('VERSION:3.0');
    buf.writeln('UID:${m.id}');
    buf.writeln('FN:${_fold(m.displayName)}');
    buf.writeln('N:${_fold(m.lastName)};${_fold(m.firstName)};;;');
    if (m.email != null) buf.writeln('EMAIL;TYPE=INTERNET:${_fold(m.email!)}');
    if (m.phone != null) buf.writeln('TEL;TYPE=CELL:${_fold(m.phone!)}');
    if (m.streetAddress != null || m.poBox != null) {
      // ADR: PO Box;Extended;Street;City;Region;PostCode;Country
      buf.writeln('ADR;TYPE=HOME:${m.poBox ?? ''};;${m.streetAddress ?? ''};;;;');
    }
    if (m.dateOfBirth != null) {
      buf.writeln('BDAY:${_formatDate(m.dateOfBirth!)}');
    }
    if (m.dateJoined != null) {
      buf.writeln('X-DATE-JOINED:${_formatDate(m.dateJoined!)}');
    }
    if (m.membershipStatus != null) {
      buf.writeln('X-MEMBERSHIP-STATUS:${m.membershipStatus}');
    }
    if (m.emergencyContactName != null) {
      buf.writeln('X-EMERGENCY-CONTACT-NAME:${_fold(m.emergencyContactName!)}');
    }
    if (m.emergencyContactPhone != null) {
      buf.writeln('X-EMERGENCY-CONTACT-PHONE:${_fold(m.emergencyContactPhone!)}');
    }
    if (m.woodworkingInduction != null) {
      buf.writeln('X-WOODWORKING-INDUCTION:${_formatDate(m.woodworkingInduction!)}');
    }
    if (m.metalworkingInduction != null) {
      buf.writeln('X-METALWORKING-INDUCTION:${_formatDate(m.metalworkingInduction!)}');
    }
    if (m.gymWaiver != null) {
      buf.writeln('X-GYM-WAIVER:${_formatDate(m.gymWaiver!)}');
    }
    buf.writeln('REV:${m.updatedAt.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').substring(0, 15)}Z');
    buf.write('END:VCARD');
    return buf.toString();
  }

  /// Parses a vCard 3.0 string into a flat map of lowercased property names
  /// to values.  Multi-value properties (ADR) are split by component.
  Map<String, String> _parseVCard(String vcard) {
    final result = <String, String>{};
    for (final raw in vcard.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('BEGIN:') || line.startsWith('END:')) {
        continue;
      }
      final colonIdx = line.indexOf(':');
      if (colonIdx < 0) continue;
      final propRaw = line.substring(0, colonIdx).toLowerCase();
      final value = line.substring(colonIdx + 1).trim();
      // Strip type parameters (e.g. EMAIL;TYPE=INTERNET → email)
      final prop = propRaw.split(';').first;
      if (prop == 'adr') {
        // ADR: PO Box;Extended;Street;City;Region;PostCode;Country
        final parts = value.split(';');
        if (parts.isNotEmpty) result['adr-pobox'] = parts[0].trim();
        if (parts.length > 2) result['adr-street'] = parts[2].trim();
      } else if (prop == 'n') {
        // N: LastName;FirstName;AdditionalNames;Prefix;Suffix
        final parts = value.split(';');
        result['n-last'] = parts.isNotEmpty ? parts[0].trim() : '';
        result['n-first'] = parts.length > 1 ? parts[1].trim() : '';
      } else {
        result[prop] = value;
      }
    }
    return result;
  }

  // ── WebDAV XML ────────────────────────────────────────────────────────────

  String _buildMultistatus(List<Member> members) {
    final buf = StringBuffer();
    buf.writeln(
        '<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
        '<multistatus xmlns="DAV:" xmlns:card="urn:ietf:params:xml:ns:carddav">');

    // Collection entry — includes current-user-principal so that macOS/iOS
    // can follow it to discover the addressbook-home-set (required for
    // "Manual" and "Automatic" account setup modes).
    buf.writeln('  <response>');
    buf.writeln('    <href>$_basePath/</href>');
    buf.writeln('    <propstat>');
    buf.writeln('      <prop>');
    buf.writeln('        <resourcetype><collection/><card:addressbook/></resourcetype>');
    buf.writeln('        <displayname>Members</displayname>');
    buf.writeln('        <current-user-principal><href>$_principalPath</href></current-user-principal>');
    buf.writeln('      </prop>');
    buf.writeln('      <status>HTTP/1.1 200 OK</status>');
    buf.writeln('    </propstat>');
    buf.writeln('  </response>');

    for (final m in members) {
      buf.writeln('  <response>');
      buf.writeln('    <href>$_basePath/${m.id}.vcf</href>');
      buf.writeln('    <propstat>');
      buf.writeln('      <prop>');
      buf.writeln('        <getetag>"${m.etag}"</getetag>');
      buf.writeln('        <getcontenttype>$_vcardType</getcontenttype>');
      buf.writeln('        <resourcetype/>');
      buf.writeln('      </prop>');
      buf.writeln('      <status>HTTP/1.1 200 OK</status>');
      buf.writeln('    </propstat>');
      buf.writeln('  </response>');
    }

    buf.write('</multistatus>');
    return buf.toString();
  }

  String _buildPrincipalResponse() => '''<?xml version="1.0" encoding="UTF-8"?>
<multistatus xmlns="DAV:" xmlns:card="urn:ietf:params:xml:ns:carddav">
  <response>
    <href>$_principalPath</href>
    <propstat>
      <prop>
        <resourcetype><principal/></resourcetype>
        <displayname>Members</displayname>
        <current-user-principal><href>$_principalPath</href></current-user-principal>
        <card:addressbook-home-set><href>$_basePath/</href></card:addressbook-home-set>
      </prop>
      <status>HTTP/1.1 200 OK</status>
    </propstat>
  </response>
</multistatus>''';

  // ── Utilities ─────────────────────────────────────────────────────────────

  static AuditChanges? _auditChanges(Request r) =>
      r.context['audit.changes'] as AuditChanges?;

  static Map<String, dynamic> _snapshot(Member m) => {
        'firstName': m.firstName,
        'lastName': m.lastName,
        'dateJoined': m.dateJoined?.toIso8601String().substring(0, 10),
        'membershipStatus': m.membershipStatus,
        'streetAddress': m.streetAddress,
        'poBox': m.poBox,
        'email': m.email,
        'phone': m.phone,
        'dateOfBirth': m.dateOfBirth?.toIso8601String().substring(0, 10),
        'emergencyContactName': m.emergencyContactName,
        'emergencyContactPhone': m.emergencyContactPhone,
        'woodworkingInduction':
            m.woodworkingInduction?.toIso8601String().substring(0, 10),
        'metalworkingInduction':
            m.metalworkingInduction?.toIso8601String().substring(0, 10),
        'gymWaiver': m.gymWaiver?.toIso8601String().substring(0, 10),
      };

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static String _stripVcf(String uid) =>
      uid.endsWith('.vcf') ? uid.substring(0, uid.length - 4) : uid;

  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Accepts both YYYYMMDD and YYYY-MM-DD
    final normalised = raw.length == 8
        ? '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}'
        : raw;
    try {
      final parts = normalised.split('-');
      return DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// vCard line folding — replaces characters that would break the format.
  static String _fold(String value) => value.replaceAll('\n', ' ').replaceAll('\r', '');

  static Response _unauthorized() => Response.unauthorized(
        jsonEncode({'error': 'Authentication required'}),
        headers: {
          'Content-Type': 'application/json',
          'WWW-Authenticate': 'Basic realm="Shedbooks Members"',
        },
      );
}
