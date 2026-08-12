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

import '../../application/contact/create_contact_use_case.dart';
import '../../application/contact/delete_contact_use_case.dart';
import '../../application/contact/get_contact_use_case.dart';
import '../../application/contact/list_contacts_use_case.dart';
import '../../application/contact/merge_contacts_use_case.dart';
import '../../application/contact/update_contact_use_case.dart';
import '../../domain/entities/contact.dart';
import '../../domain/enums/app_role.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../audit_changes.dart';
import '../dto/contact_response.dart';
import '../dto/create_contact_request.dart';
import '../dto/update_contact_request.dart';
import 'handler_diff.dart';

/// Shelf request handlers for the /contacts resource.
class ContactHandler {
  final CreateContactUseCase _create;
  final GetContactUseCase _get;
  final ListContactsUseCase _list;
  final UpdateContactUseCase _update;
  final DeleteContactUseCase _delete;
  final MergeContactsUseCase _merge;

  const ContactHandler({
    required CreateContactUseCase create,
    required GetContactUseCase get,
    required ListContactsUseCase list,
    required UpdateContactUseCase update,
    required DeleteContactUseCase delete,
    required MergeContactsUseCase merge,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _merge = merge;

  /// GET /contacts
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final role = _userRole(request);
    final isAuthorized = role.atLeast(AppRole.administrator);

    final contacts = await _list.execute(entityId: entityId);
    final body = jsonEncode(
      contacts.map((c) {
        final contact = isAuthorized ? c : _redact(c);
        return ContactResponse.fromEntity(contact).toJson();
      }).toList(),
    );
    return Response.ok(body, headers: _jsonHeaders);
  }

  /// POST /contacts
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final CreateContactRequest dto;
    try {
      dto = CreateContactRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final contact = await _create.execute(
        entityId: entityId,
        name: dto.name,
        contactType: dto.contactType,
        gstRegistered: dto.gstRegistered,
        abn: dto.abn,
        bsb: dto.bsb,
        accountNumber: dto.accountNumber,
        address: dto.address,
      );
      _auditChanges(request)?.set(_contactSnapshot(contact, redact: true));
      final role = _userRole(request);
      final isAuthorized = role.atLeast(AppRole.administrator);
      final result = isAuthorized ? contact : _redact(contact);
      return Response(
        201,
        body: ContactResponse.fromEntity(result).toJsonString(),
        headers: _jsonHeaders,
      );
    } on ContactValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /contacts/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final role = _userRole(request);
    final isAuthorized = role.atLeast(AppRole.administrator);

    try {
      final contact = await _get.execute(id, entityId: entityId);
      final result = isAuthorized ? contact : _redact(contact);
      return Response.ok(
        ContactResponse.fromEntity(result).toJsonString(),
        headers: _jsonHeaders,
      );
    } on ContactNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /contacts/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final role = _userRole(request);
    final isAuthorized = role.atLeast(AppRole.administrator);

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final UpdateContactRequest dto;
    try {
      dto = UpdateContactRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    Contact? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      final contact = await _update.execute(
        id: id,
        entityId: entityId,
        name: dto.name,
        contactType: dto.contactType,
        gstRegistered: dto.gstRegistered,
        abn: dto.abn,
        bsb: isAuthorized ? dto.bsb : before?.bsb,
        accountNumber: isAuthorized ? dto.accountNumber : before?.accountNumber,
        address: dto.address,
      );
      if (before != null) {
        final bSnap = _contactSnapshot(before, redact: true);
        final aSnap = _contactSnapshot(contact, redact: true);
        final diff = diffMaps(bSnap, aSnap);
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      final result = isAuthorized ? contact : _redact(contact);
      return Response.ok(
        ContactResponse.fromEntity(result).toJsonString(),
        headers: _jsonHeaders,
      );
    } on ContactNotFoundException catch (e) {
      return _notFound(e.message);
    } on ContactValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// DELETE /contacts/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    Contact? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) _auditChanges(request)?.set(_contactSnapshot(before));
      return Response(204);
    } on ContactNotFoundException catch (e) {
      return _notFound(e.message);
    } on ContactInUseException catch (e) {
      return _conflict(e.message);
    }
  }

  /// POST /contacts/merge
  ///
  /// Body: `{ "keepId": "<uuid>", "mergeIds": ["<uuid>", ...] }`
  ///
  /// Reassigns all transactions from the merge contacts to the kept contact,
  /// soft-deletes the merge contacts, and returns the surviving contact.
  Future<Response> handleMerge(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final keepId = json['keepId'] as String?;
    final mergeIdsRaw = json['mergeIds'];

    if (keepId == null || keepId.isEmpty) {
      return _badRequest('keepId is required');
    }
    if (mergeIdsRaw is! List || mergeIdsRaw.isEmpty) {
      return _badRequest('mergeIds must be a non-empty list');
    }
    final mergeIds = mergeIdsRaw.cast<String>();
    if (mergeIds.contains(keepId)) {
      return _badRequest('keepId must not appear in mergeIds');
    }

    try {
      final (:kept, :mergedNames) = await _merge.execute(
        keepId: keepId,
        mergeIds: mergeIds,
        entityId: entityId,
      );
      _auditChanges(request)?.set({
        'kept': kept.name,
        'merged': mergedNames,
      });
      return Response.ok(
        ContactResponse.fromEntity(kept).toJsonString(),
        headers: _jsonHeaders,
      );
    } on ContactNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AppRole _userRole(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    final roles = claims?['https://shedbooks.com/roles'] as List<dynamic>? ?? [];
    return AppRole.fromClaims(roles);
  }

  static Contact _redact(Contact c) => Contact(
        id: c.id,
        name: c.name,
        contactType: c.contactType,
        gstRegistered: c.gstRegistered,
        abn: c.abn,
        bsb: null,
        accountNumber: null,
        address: c.address,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        deletedAt: c.deletedAt,
      );

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  static Map<String, dynamic> _contactSnapshot(Contact c, {bool redact = false}) =>
      {
        'name': c.name,
        'contactType': c.contactType.name,
        'gstRegistered': c.gstRegistered,
        'abn': c.abn,
        'bsb': redact ? (c.bsb != null ? '***' : null) : c.bsb,
        'accountNumber':
            redact ? (c.accountNumber != null ? '***' : null) : c.accountNumber,
        'address': c.address,
      };

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _notFound(String message) => Response.notFound(
        jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static Response _conflict(String message) => Response(
        409,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );
}
