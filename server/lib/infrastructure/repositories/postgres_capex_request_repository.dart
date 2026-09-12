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

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/capex_request.dart';
import '../../domain/enums/capex_request_status.dart';
import '../../domain/exceptions/capex_request_exception.dart';
import '../../domain/repositories/i_capex_request_repository.dart';

/// PostgreSQL implementation of [ICapexRequestRepository].
class PostgresCapexRequestRepository implements ICapexRequestRepository {
  final Pool _pool;
  final Uuid _uuid;

  PostgresCapexRequestRepository(this._pool, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  static const _cols =
      'id, entity_id, request_no, request_date, prepared_by_name, description, '
      'what_is_requested, need_or_benefit, alternatives_considered, '
      'purchase_cost_cents, ongoing_costs_cents, other_costs_cents, cost_notes, '
      'total_amount_cents, quotes_received_count, status, decision_by_name, '
      'decision_at, decision_notes, created_at, updated_at, deleted_at';

  @override
  Future<CapexRequest> create({
    required String entityId,
    required String requestNo,
    required DateTime requestDate,
    required String preparedByName,
    required String description,
    required String whatIsRequested,
    required String needOrBenefit,
    String? alternativesConsidered,
    required int purchaseCostCents,
    int? ongoingCostsCents,
    int? otherCostsCents,
    String? costNotes,
    required int totalAmountCents,
    int? quotesReceivedCount,
  }) async {
    final id = _uuid.v4();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO capex_requests
          (id, entity_id, request_no, request_date, prepared_by_name, description,
           what_is_requested, need_or_benefit, alternatives_considered,
           purchase_cost_cents, ongoing_costs_cents, other_costs_cents, cost_notes,
           total_amount_cents, quotes_received_count)
        VALUES (
          @id::uuid, @entityId, @requestNo, @requestDate::date, @preparedByName, @description,
          @whatIsRequested, @needOrBenefit, @alternativesConsidered,
          @purchaseCostCents, @ongoingCostsCents, @otherCostsCents, @costNotes,
          @totalAmountCents, @quotesReceivedCount
        )
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'requestNo': requestNo,
        'requestDate': _dateStr(requestDate),
        'preparedByName': preparedByName,
        'description': description,
        'whatIsRequested': whatIsRequested,
        'needOrBenefit': needOrBenefit,
        'alternativesConsidered': alternativesConsidered,
        'purchaseCostCents': purchaseCostCents,
        'ongoingCostsCents': ongoingCostsCents,
        'otherCostsCents': otherCostsCents,
        'costNotes': costNotes,
        'totalAmountCents': totalAmountCents,
        'quotesReceivedCount': quotesReceivedCount,
      },
    );
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<CapexRequest?> findById(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols FROM capex_requests
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.isEmpty) return null;
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<List<CapexRequest>> findAll({required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_cols FROM capex_requests
        WHERE entity_id = @entityId AND deleted_at IS NULL
        ORDER BY request_date DESC, created_at DESC
      '''),
      parameters: {'entityId': entityId},
    );
    return result.map((r) => _mapRow(r.toColumnMap())).toList();
  }

  @override
  Future<CapexRequest> update({
    required String id,
    required String entityId,
    required String requestNo,
    required DateTime requestDate,
    required String preparedByName,
    required String description,
    required String whatIsRequested,
    required String needOrBenefit,
    String? alternativesConsidered,
    required int purchaseCostCents,
    int? ongoingCostsCents,
    int? otherCostsCents,
    String? costNotes,
    required int totalAmountCents,
    int? quotesReceivedCount,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE capex_requests
        SET request_no                = @requestNo,
            request_date              = @requestDate::date,
            prepared_by_name          = @preparedByName,
            description               = @description,
            what_is_requested         = @whatIsRequested,
            need_or_benefit           = @needOrBenefit,
            alternatives_considered   = @alternativesConsidered,
            purchase_cost_cents       = @purchaseCostCents,
            ongoing_costs_cents       = @ongoingCostsCents,
            other_costs_cents         = @otherCostsCents,
            cost_notes                = @costNotes,
            total_amount_cents        = @totalAmountCents,
            quotes_received_count     = @quotesReceivedCount,
            updated_at                = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'requestNo': requestNo,
        'requestDate': _dateStr(requestDate),
        'preparedByName': preparedByName,
        'description': description,
        'whatIsRequested': whatIsRequested,
        'needOrBenefit': needOrBenefit,
        'alternativesConsidered': alternativesConsidered,
        'purchaseCostCents': purchaseCostCents,
        'ongoingCostsCents': ongoingCostsCents,
        'otherCostsCents': otherCostsCents,
        'costNotes': costNotes,
        'totalAmountCents': totalAmountCents,
        'quotesReceivedCount': quotesReceivedCount,
      },
    );
    if (result.isEmpty) throw CapexRequestNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<CapexRequest> decide({
    required String id,
    required String entityId,
    required CapexRequestStatus status,
    required String decisionByName,
    String? decisionNotes,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE capex_requests
        SET status           = @status,
            decision_by_name = @decisionByName,
            decision_at      = NOW(),
            decision_notes   = @decisionNotes,
            updated_at       = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
        RETURNING $_cols
      '''),
      parameters: {
        'id': id,
        'entityId': entityId,
        'status': status.name,
        'decisionByName': decisionByName,
        'decisionNotes': decisionNotes,
      },
    );
    if (result.isEmpty) throw CapexRequestNotFoundException(id);
    return _mapRow(result.first.toColumnMap());
  }

  @override
  Future<void> delete(String id, {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE capex_requests
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE id = @id::uuid AND entity_id = @entityId AND deleted_at IS NULL
      '''),
      parameters: {'id': id, 'entityId': entityId},
    );
    if (result.affectedRows == 0) throw CapexRequestNotFoundException(id);
  }

  @override
  Future<List<String>> findRequestNosLike(String pattern,
      {required String entityId}) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT DISTINCT request_no
        FROM capex_requests
        WHERE entity_id = @entityId
          AND deleted_at IS NULL
          AND request_no LIKE @pattern
      '''),
      parameters: {'entityId': entityId, 'pattern': pattern},
    );
    return result.map((r) => r[0] as String).toList();
  }

  static String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);

  static CapexRequest _mapRow(Map<String, dynamic> row) {
    final requestDate = row['request_date'] as DateTime;
    final decisionAt = row['decision_at'] as DateTime?;
    return CapexRequest(
      id: row['id'].toString(),
      entityId: row['entity_id'] as String,
      requestNo: row['request_no'] as String,
      requestDate:
          DateTime.utc(requestDate.year, requestDate.month, requestDate.day),
      preparedByName: row['prepared_by_name'] as String,
      description: row['description'] as String,
      whatIsRequested: row['what_is_requested'] as String,
      needOrBenefit: row['need_or_benefit'] as String,
      alternativesConsidered: row['alternatives_considered'] as String?,
      purchaseCostCents: (row['purchase_cost_cents'] as num).toInt(),
      ongoingCostsCents: row['ongoing_costs_cents'] == null
          ? null
          : (row['ongoing_costs_cents'] as num).toInt(),
      otherCostsCents: row['other_costs_cents'] == null
          ? null
          : (row['other_costs_cents'] as num).toInt(),
      costNotes: row['cost_notes'] as String?,
      totalAmountCents: (row['total_amount_cents'] as num).toInt(),
      quotesReceivedCount: row['quotes_received_count'] as int?,
      status: CapexRequestStatus.fromValue(row['status'] as String),
      decisionByName: row['decision_by_name'] as String?,
      decisionAt: decisionAt,
      decisionNotes: row['decision_notes'] as String?,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      deletedAt: row['deleted_at'] as DateTime?,
    );
  }
}
