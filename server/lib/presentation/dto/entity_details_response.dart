import 'dart:convert';

import '../../domain/entities/entity_details.dart';

/// Response DTO for entity details.
class EntityDetailsResponse {
  final String name;
  final String abn;
  final String incorporationIdentifier;

  const EntityDetailsResponse({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
  });

  factory EntityDetailsResponse.fromEntity(EntityDetails e) =>
      EntityDetailsResponse(
        name: e.name,
        abn: e.abn,
        incorporationIdentifier: e.incorporationIdentifier,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'abn': abn,
        'incorporationIdentifier': incorporationIdentifier,
      };

  String toJsonString() => jsonEncode(toJson());
}
