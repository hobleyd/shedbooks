import 'dart:convert';
import '../../domain/entities/contact.dart';

/// JSON response shape for a contact.
class ContactResponse {
  final String id;
  final String name;
  final String contactType;
  final bool gstRegistered;
  final String? abn;
  final String? bsb;
  final String? accountNumber;
  final String createdAt;
  final String updatedAt;

  const ContactResponse({
    required this.id,
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
    this.bsb,
    this.accountNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContactResponse.fromEntity(Contact entity) {
    return ContactResponse(
      id: entity.id,
      name: entity.name,
      contactType: entity.contactType.name,
      gstRegistered: entity.gstRegistered,
      abn: entity.abn,
      bsb: entity.bsb,
      accountNumber: entity.accountNumber,
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactType': contactType,
        'gstRegistered': gstRegistered,
        'abn': abn,
        'bsb': bsb,
        'accountNumber': accountNumber,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
