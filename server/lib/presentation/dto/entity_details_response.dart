import 'dart:convert';

import '../../domain/entities/entity_details.dart';

/// Response DTO for entity details.
class EntityDetailsResponse {
  final String name;
  final String abn;
  final String incorporationIdentifier;
  final String moneyInReceiptFormat;
  final String moneyOutReceiptFormat;

  const EntityDetailsResponse({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
  });

  factory EntityDetailsResponse.fromEntity(EntityDetails e) =>
      EntityDetailsResponse(
        name: e.name,
        abn: e.abn,
        incorporationIdentifier: e.incorporationIdentifier,
        moneyInReceiptFormat: e.moneyInReceiptFormat,
        moneyOutReceiptFormat: e.moneyOutReceiptFormat,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'abn': abn,
        'incorporationIdentifier': incorporationIdentifier,
        'moneyInReceiptFormat': moneyInReceiptFormat,
        'moneyOutReceiptFormat': moneyOutReceiptFormat,
      };

  String toJsonString() => jsonEncode(toJson());
}
