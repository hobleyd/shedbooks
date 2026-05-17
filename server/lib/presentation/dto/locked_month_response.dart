import 'dart:convert';
import 'dart:io';

import '../../domain/entities/locked_month.dart';

/// JSON response shape for a single locked month.
class LockedMonthResponse {
  final String monthYear;
  final String lockedAt;

  const LockedMonthResponse({
    required this.monthYear,
    required this.lockedAt,
  });

  factory LockedMonthResponse.fromEntity(LockedMonth entity) =>
      LockedMonthResponse(
        monthYear: entity.monthYear,
        lockedAt: entity.lockedAt.toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'monthYear': monthYear,
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
