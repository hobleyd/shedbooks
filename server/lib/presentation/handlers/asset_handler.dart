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

import '../../application/asset/create_asset_use_case.dart';
import '../../application/asset/delete_asset_use_case.dart';
import '../../application/asset/get_asset_use_case.dart';
import '../../application/asset/import_assets_use_case.dart';
import '../../application/asset/list_assets_use_case.dart';
import '../../application/asset/update_asset_use_case.dart';
import '../../domain/entities/asset.dart';
import '../../domain/exceptions/asset_exception.dart';
import '../audit_changes.dart';
import '../dto/asset_response.dart';
import '../dto/create_asset_request.dart';
import '../dto/import_asset_request.dart';
import 'handler_diff.dart';

/// Shelf request handlers for the /assets REST resource.
class AssetHandler {
  final CreateAssetUseCase _create;
  final GetAssetUseCase _get;
  final ListAssetsUseCase _list;
  final UpdateAssetUseCase _update;
  final DeleteAssetUseCase _delete;
  final ImportAssetsUseCase _import;

  const AssetHandler({
    required CreateAssetUseCase create,
    required GetAssetUseCase get,
    required ListAssetsUseCase list,
    required UpdateAssetUseCase update,
    required DeleteAssetUseCase delete,
    required ImportAssetsUseCase import,
  })  : _create = create,
        _get = get,
        _list = list,
        _update = update,
        _delete = delete,
        _import = import;

  /// GET /assets
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();
    final assets = await _list.execute(entityId: entityId);
    return Response.ok(
      jsonEncode(assets.map((a) => AssetResponse.fromEntity(a).toJson()).toList()),
      headers: _jsonHeaders,
    );
  }

  /// POST /assets
  Future<Response> handleCreate(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final CreateAssetRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = CreateAssetRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    try {
      final asset = await _create.execute(
        entityId: entityId,
        assetNo: dto.assetNo,
        assetType: dto.assetType,
        description: dto.description,
        brand: dto.brand,
        identification: dto.identification,
        serialNo: dto.serialNo,
        manufactureYear: dto.manufactureYear,
        estimatedMarketValueCents: dto.estimatedMarketValueCents,
      );
      _auditChanges(request)?.set(_snapshot(asset));
      return Response(
        201,
        body: AssetResponse.fromEntity(asset).toJsonString(),
        headers: _jsonHeaders,
      );
    } on AssetValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// GET /assets/:id
  Future<Response> handleGet(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();
    try {
      final asset = await _get.execute(id, entityId: entityId);
      return Response.ok(
        AssetResponse.fromEntity(asset).toJsonString(),
        headers: _jsonHeaders,
      );
    } on AssetNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// PUT /assets/:id
  Future<Response> handleUpdate(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final CreateAssetRequest dto;
    try {
      final json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      dto = CreateAssetRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    Asset? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      final asset = await _update.execute(
        id: id,
        entityId: entityId,
        assetNo: dto.assetNo,
        assetType: dto.assetType,
        description: dto.description,
        brand: dto.brand,
        identification: dto.identification,
        serialNo: dto.serialNo,
        manufactureYear: dto.manufactureYear,
        estimatedMarketValueCents: dto.estimatedMarketValueCents,
      );
      if (before != null) {
        final diff = diffMaps(_snapshot(before), _snapshot(asset));
        if (diff.isNotEmpty) _auditChanges(request)?.set(diff);
      }
      return Response.ok(
        AssetResponse.fromEntity(asset).toJsonString(),
        headers: _jsonHeaders,
      );
    } on AssetNotFoundException catch (e) {
      return _notFound(e.message);
    } on AssetValidationException catch (e) {
      return _badRequest(e.message);
    }
  }

  /// DELETE /assets/:id
  Future<Response> handleDelete(Request request, String id) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    Asset? before;
    try {
      before = await _get.execute(id, entityId: entityId);
    } catch (_) {}

    try {
      await _delete.execute(id, entityId: entityId);
      if (before != null) _auditChanges(request)?.set(_snapshot(before));
      return Response(204);
    } on AssetNotFoundException catch (e) {
      return _notFound(e.message);
    }
  }

  /// POST /assets/import — reentrant bulk upsert from XLSX.
  ///
  /// Accepts: `[{ assetNo, assetType, description, brand, ... }, ...]`
  /// Returns the list of upserted assets on success.
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

    final ImportAssetsRequest dto;
    try {
      dto = ImportAssetsRequest.fromJson(jsonArray);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final assets = await _import.execute(
        entityId: entityId,
        assets: dto.assets,
      );
      _auditChanges(request)?.set({'imported': assets.length});
      return Response(
        201,
        body: jsonEncode(
          assets.map((a) => AssetResponse.fromEntity(a).toJson()).toList(),
        ),
        headers: _jsonHeaders,
      );
    } on AssetValidationException catch (e) {
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

  static Map<String, dynamic> _snapshot(Asset a) => {
        'assetNo': a.assetNo,
        'assetType': a.assetType,
        'description': a.description,
        'brand': a.brand,
        'identification': a.identification,
        'serialNo': a.serialNo,
        'manufactureYear': a.manufactureYear,
        'estimatedMarketValueCents': a.estimatedMarketValueCents,
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
