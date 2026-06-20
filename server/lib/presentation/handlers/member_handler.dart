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
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../application/member/create_member_use_case.dart';
import '../../application/member/delete_member_use_case.dart';
import '../../application/member/get_member_use_case.dart';
import '../../application/member/import_members_use_case.dart';
import '../../application/member/list_members_use_case.dart';
import '../../application/member/update_member_use_case.dart';
import '../../domain/entities/member.dart';
import '../../domain/exceptions/member_exception.dart';
import '../audit_changes.dart';
import '../dto/create_member_request.dart';
import '../dto/import_member_request.dart';
import '../dto/member_response.dart';
import 'handler_diff.dart';

/// Shelf request handlers for the /members REST resource.
class MemberHandler {
  final CreateMemberUseCase _create;
  final GetMemberUseCase _get;
  final ListMembersUseCase _list;
  final UpdateMemberUseCase _update;
  final DeleteMemberUseCase _delete;
  final ImportMembersUseCase _import;

  const MemberHandler({
    required CreateMemberUseCase create,
    required GetMemberUseCase get,
    required ListMembersUseCase list,
    required UpdateMemberUseCase update,
    required DeleteMemberUseCase delete,
    required ImportMembersUseCase import,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _import = import;

  /// GET /members
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();
    final members = await _list.execute(entityId: entityId);
    return Response.ok(
      jsonEncode(members.map((m) => MemberResponse.fromEntity(m).toJson()).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /members
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final CreateMemberRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = CreateMemberRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    try {
      final member = await _create.execute(
        entityId: entityId,
        firstName: dto.firstName,
        lastName: dto.lastName,
        dateJoined: dto.dateJoined,
        membershipStatus: dto.membershipStatus,
        streetAddress: dto.streetAddress,
        poBox: dto.poBox,
        email: dto.email,
        phone: dto.phone,
        dateOfBirth: dto.dateOfBirth,
        emergencyContact: dto.emergencyContact,
        woodworkingInduction: dto.woodworkingInduction,
        metalworkingInduction: dto.metalworkingInduction,
        gymWaiver: dto.gymWaiver,
      );
      _auditChanges(request)?.set(_snapshot(member));
      return Response(
        201,
        body: MemberResponse.fromEntity(member).toJsonString(),
        headers: _jsonHeaders,
      );
    } on MemberValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /members/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();
    try {
      final member = await _get.execute(id, entityId: entityId);
      return Response.ok(
        MemberResponse.fromEntity(member).toJsonString(),
        headers: _jsonHeaders,
      );
    } on MemberNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /members/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final CreateMemberRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = CreateMemberRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    Member? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      final member = await _update.execute(
        id: id,
        entityId: entityId,
        firstName: dto.firstName,
        lastName: dto.lastName,
        dateJoined: dto.dateJoined,
        membershipStatus: dto.membershipStatus,
        streetAddress: dto.streetAddress,
        poBox: dto.poBox,
        email: dto.email,
        phone: dto.phone,
        dateOfBirth: dto.dateOfBirth,
        emergencyContact: dto.emergencyContact,
        woodworkingInduction: dto.woodworkingInduction,
        metalworkingInduction: dto.metalworkingInduction,
        gymWaiver: dto.gymWaiver,
      );
      if (before != null) {
        final diff = diffMaps(_snapshot(before), _snapshot(member));
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      return Response.ok(
        MemberResponse.fromEntity(member).toJsonString(),
        headers: _jsonHeaders,
      );
    } on MemberNotFoundException catch (e) {
      return _notFound(e.message);
    } on MemberValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// DELETE /members/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    Member? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) _auditChanges(request)?.set(_snapshot(before));
      return Response(204);
    } on MemberNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// POST /members/import — bulk-creates members from a JSON array.
  ///
  /// Accepts: `[{ name, dateJoined, membershipStatus, ... }, ...]`
  /// Returns the list of created members on success.
  Future<Response> handleImport(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final List<dynamic> jsonArray;
    try {
      final body = await request.readAsString();
      jsonArray = jsonDecode(body) as List<dynamic>;
    } catch (_) {
      return _badRequest('Request body must be a JSON array');
    }

    final ImportMembersRequest dto;
    try {
      dto = ImportMembersRequest.fromJson(jsonArray);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final members = await _import.execute(
        entityId: entityId,
        members: dto.members,
      );
      _auditChanges(request)?.set({'imported': members.length});
      return Response(
        201,
        body: jsonEncode(
          members.map((m) => MemberResponse.fromEntity(m).toJson()).toList(),
        ),
        headers: _jsonHeaders,
      );
    } on MemberValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

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
        'emergencyContact': m.emergencyContact,
        'woodworkingInduction':
            m.woodworkingInduction?.toIso8601String().substring(0, 10),
        'metalworkingInduction':
            m.metalworkingInduction?.toIso8601String().substring(0, 10),
        'gymWaiver': m.gymWaiver?.toIso8601String().substring(0, 10),
      };

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _notFound(String message) => Response.notFound(
        jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
