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

import '../../application/closing_bank_balance/list_closing_bank_balances_use_case.dart';
import '../../application/closing_bank_balance/save_closing_bank_balance_use_case.dart';
import '../../application/locked_month/list_locked_months_use_case.dart';
import '../../application/locked_month/lock_month_use_case.dart';
import '../../application/locked_month/unlock_month_use_case.dart';
import '../audit_changes.dart';
import '../dto/lock_month_request.dart';
import '../dto/locked_month_response.dart';

/// Shelf request handlers for the /locked-months resource.
class LockedMonthHandler {
  final ListLockedMonthsUseCase _list;
  final LockMonthUseCase _lock;
  final UnlockMonthUseCase _unlock;
  final ListClosingBankBalancesUseCase _listBalances;
  final SaveClosingBankBalanceUseCase _saveBalance;

  const LockedMonthHandler({
    required ListLockedMonthsUseCase list,
    required LockMonthUseCase lock,
    required UnlockMonthUseCase unlock,
    required ListClosingBankBalancesUseCase listBalances,
    required SaveClosingBankBalanceUseCase saveBalance,
  })  : _list = list,
        _lock = lock,
        _unlock = unlock,
        _listBalances = listBalances,
        _saveBalance = saveBalance;

  /// GET /locked-months
  Future<Response> handleList(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final months = await _list.execute(entityId);
    return Response.ok(
      LockedMonthResponse.toJsonList(months),
      headers: _jsonHeaders,
    );
  }

  /// POST /locked-months
  Future<Response> handleLock(Request request) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Request body must be valid JSON');
    }

    final LockMonthRequest dto;
    try {
      dto = LockMonthRequest.fromJson(json);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _lock.execute(entityId, dto.monthYear, dto.bankAccountId);
      if (dto.carryOverBalance) {
        await _carryOverBalance(entityId, dto.bankAccountId, dto.monthYear);
      }
      (request.context['audit.changes'] as AuditChanges?)?.set({
        'monthYear': dto.monthYear,
        'bankAccountId': dto.bankAccountId,
        if (dto.carryOverBalance) 'carryOverBalance': true,
      });
    } on ArgumentError catch (e) {
      return _badRequest(e.message.toString());
    }

    return Response(204);
  }

  /// DELETE /locked-months/:monthYear/:bankAccountId
  Future<Response> handleUnlock(
      Request request, String monthYear, String bankAccountId) async {
    final entityId = _entityId(request);
    if (entityId == null) return _orgRequired();

    await _unlock.execute(entityId, monthYear, bankAccountId);
    (request.context['audit.changes'] as AuditChanges?)?.set({
      'monthYear': monthYear,
      'bankAccountId': bankAccountId,
    });
    return Response(204);
  }

  /// Copies the most recent prior closing balance for [bankAccountId] to the
  /// last day of [monthYear]. No-ops if no prior balance exists.
  Future<void> _carryOverBalance(
      String entityId, String bankAccountId, String monthYear) async {
    final parts = monthYear.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // Last calendar day of the locked month.
    final lastDay = DateTime(year, month + 1, 0);
    final lastDayStr =
        '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

    final balances = await _listBalances.execute(
      entityId: entityId,
      bankAccountId: bankAccountId,
    );

    // Find the most recent balance that predates the end of this month.
    final prior = balances.where((b) => b.balanceDate.compareTo(lastDayStr) < 0);
    if (prior.isEmpty) return;

    final source = prior.first; // ordered desc, so first = most recent

    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    await _saveBalance.execute(
      entityId: entityId,
      bankAccountId: bankAccountId,
      balanceDate: lastDayStr,
      balanceCents: source.balanceCents,
      statementPeriod: '${monthNames[month]} $year',
    );
  }

  static String? _entityId(Request request) {
    final claims = request.context['auth.claims'] as Map<String, dynamic>?;
    return claims?['https://shedbooks.com/entity_id'] as String?;
  }

  static Response _orgRequired() => Response.unauthorized(
        jsonEncode({'error': 'Organization authentication required'}),
        headers: _jsonHeaders,
      );

  static Response _badRequest(String message) => Response(
        400,
        body: jsonEncode({'error': message}),
        headers: _jsonHeaders,
      );

  static const Map<String, String> _jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
