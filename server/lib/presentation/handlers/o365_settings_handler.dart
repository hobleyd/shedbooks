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

import '../../application/o365/generate_o365_certificate_use_case.dart';
import '../../application/o365/get_o365_sync_settings_use_case.dart';
import '../../application/o365/save_o365_sync_settings_use_case.dart';
import '../../domain/entities/o365_sync_settings.dart';
import '../../domain/exceptions/o365_sync_exception.dart';
import '../audit_changes.dart';
import '../dto/generate_o365_certificate_request.dart';
import '../dto/generate_o365_certificate_response.dart';
import '../dto/o365_sync_settings_response.dart';
import '../dto/save_o365_sync_settings_request.dart';

/// Shelf request handlers for /admin/o365-settings.
///
/// Mounted admin-only in the router — no additional role checks needed here.
class O365SettingsHandler {
  final GetO365SyncSettingsUseCase _get;
  final SaveO365SyncSettingsUseCase _save;
  final GenerateO365CertificateUseCase _generateCertificate;

  const O365SettingsHandler({
    required GetO365SyncSettingsUseCase get,
    required SaveO365SyncSettingsUseCase save,
    required GenerateO365CertificateUseCase generateCertificate,
  })  : _get = get,
        _save = save,
        _generateCertificate = generateCertificate;

  /// GET /admin/o365-settings — returns 404 when not yet configured.
  Future<Response> handleGet(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final settings = await _get.execute(entityId);
    if (settings == null) return _notFound('O365 sync has not been configured');

    return Response.ok(
      O365SyncSettingsResponse.fromEntity(settings).toJsonString(),
      headers: _jsonHeaders,
    );
  }

  /// PUT /admin/o365-settings — creates or updates.
  Future<Response> handleSave(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final SaveO365SyncSettingsRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = SaveO365SyncSettingsRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final before = await _get.execute(entityId);

    try {
      final settings = await _save.execute(
        entityId: entityId,
        tenantId: dto.tenantId,
        clientId: dto.clientId,
        certificatePfxBase64: dto.certificatePfxBase64,
        certificatePassword: dto.certificatePassword,
      );
      _auditChanges(request)?.set({
        'before': before != null ? _snapshot(before) : null,
        'after': _snapshot(settings),
      });
      return Response.ok(
        O365SyncSettingsResponse.fromEntity(settings).toJsonString(),
        headers: _jsonHeaders,
      );
    } on O365SyncValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// POST /admin/o365-settings/generate-certificate — generates a new
  /// self-signed certificate and saves it immediately, in the same request.
  ///
  /// The private key must never round-trip through the browser, so unlike
  /// [handleSave] this does not hand the certificate back for a later
  /// `PUT`: it calls [_save] itself with the freshly generated PFX, and
  /// only ever returns the public certificate. This is a real write, so
  /// (unlike a pure-compute endpoint) it is audited via the normal
  /// `/admin/` rule in `audit_middleware.dart`.
  Future<Response> handleGenerateCertificate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final GenerateO365CertificateRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = GenerateO365CertificateRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final before = await _get.execute(entityId);

    try {
      final cert = await _generateCertificate.execute(password: dto.password);
      final settings = await _save.execute(
        entityId: entityId,
        tenantId: dto.tenantId,
        clientId: dto.clientId,
        certificatePfxBase64: cert.pfxBase64,
        certificatePassword: dto.password,
        certificateExpiresAt: cert.expiresAt,
      );
      _auditChanges(request)?.set({
        'before': before != null ? _snapshot(before) : null,
        'after': _snapshot(settings),
      });
      return Response.ok(
        GenerateO365CertificateResponse.fromResult(
          settings: settings,
          publicCertBase64: cert.publicCertBase64,
        ).toJsonString(),
        headers: _jsonHeaders,
      );
    } on O365SyncValidationException catch (e) {
      return _badRequest(e.message);
    } on O365CertificateGenerationException catch (e) {
      return _generationFailed(e.message);
    }
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static AuditChanges? _auditChanges(Request request) =>
      request.context['audit.changes'] as AuditChanges?;

  // Never include the certificate or its password in the audit trail, even
  // redacted-value diffing — just whether one is configured.
  static Map<String, dynamic> _snapshot(O365SyncSettings s) => {
        'tenantId': s.tenantId,
        'clientId': s.clientId,
        'certificate': '***',
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

  static Response _generationFailed(String message) => Response(
        502,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
