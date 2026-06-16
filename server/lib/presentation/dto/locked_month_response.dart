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

import '../../domain/entities/locked_month.dart';

/// JSON response shape for a single locked month.
class LockedMonthResponse {
  final String monthYear;
  final String bankAccountId;
  final String lockedAt;

  const LockedMonthResponse({
    required this.monthYear,
    required this.bankAccountId,
    required this.lockedAt,
  });

  factory LockedMonthResponse.fromEntity(LockedMonth entity) =>
      LockedMonthResponse(
        monthYear: entity.monthYear,
        bankAccountId: entity.bankAccountId,
        lockedAt: entity.lockedAt.toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'monthYear': monthYear,
        'bankAccountId': bankAccountId,
        'lockedAt': lockedAt,
      };

  String toJsonString() => jsonEncode(toJson());

  static String toJsonList(List<LockedMonth> entities) => jsonEncode(
        entities.map((e) => LockedMonthResponse.fromEntity(e).toJson()).toList(),
      );

  static const Map<String, String> jsonHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
