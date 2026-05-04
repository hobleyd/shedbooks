import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../../application/contact/create_contact_use_case.dart';
import '../../application/contact/delete_contact_use_case.dart';
import '../../application/contact/get_contact_use_case.dart';
import '../../application/contact/list_contacts_use_case.dart';
import '../../application/contact/update_contact_use_case.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../dto/contact_response.dart';
import '../dto/create_contact_request.dart';
import '../dto/update_contact_request.dart';

/// Shelf request handlers for the /contacts resource.
class ContactHandler {
  final CreateContactUseCase _create;
  final GetContactUseCase _get;
  final ListContactsUseCase _list;
  final UpdateContactUseCase _update;
  final DeleteContactUseCase _delete;

  const ContactHandler({
    required CreateContactUseCase create,
    required GetContactUseCase get,
    required ListContactsUseCase list,
    required UpdateContactUseCase update,
    required DeleteContactUseCase delete,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete;

  /// GET /contacts
  Future<Response> handleList(Request request) async {
    final contacts = await _list.execute();
    final body = jsonEncode(
      contacts.map((c) => ContactResponse.fromEntity(c).toJson()).toList(),
    );
    return Response.ok(body, headers: _jsonHeaders);
  }

  /// POST /contacts
  Future<Response> handleCreate(Request request) async {
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
        name: dto.name,
        contactType: dto.contactType,
        gstRegistered: dto.gstRegistered,
      );
      return Response(
        201,
        body: ContactResponse.fromEntity(contact).toJsonString(),
        headers: _jsonHeaders,
      );
    } on ContactValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /contacts/:id
  Future<Response> handleGet(Request request, String id) async {
    try {
      final contact = await _get.execute(id);
      return Response.ok(
        ContactResponse.fromEntity(contact).toJsonString(),
        headers: _jsonHeaders,
      );
    } on ContactNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /contacts/:id
  Future<Response> handleUpdate(Request request, String id) async {
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

    try {
      final contact = await _update.execute(
        id: id,
        name: dto.name,
        contactType: dto.contactType,
        gstRegistered: dto.gstRegistered,
      );
      return Response.ok(
        ContactResponse.fromEntity(contact).toJsonString(),
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
    try {
      await _delete.execute(id);
      return Response(204);
    } on ContactNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  static const Map<String, String> _jsonHeaders = {
    'content-type': 'application/json',
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
}
