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
