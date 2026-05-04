import 'dart:convert';
import '../../domain/entities/contact.dart';

/// JSON response shape for a contact.
class ContactResponse {
  final String id;
  final String name;
  final String contactType;
  final bool gstRegistered;
  final String createdAt;
  final String updatedAt;

  const ContactResponse({
    required this.id,
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContactResponse.fromEntity(Contact entity) {
    return ContactResponse(
      id: entity.id,
      name: entity.name,
      contactType: entity.contactType.name,
      gstRegistered: entity.gstRegistered,
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactType': contactType,
        'gstRegistered': gstRegistered,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
