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
  final String? address;
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
    this.address,
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
      address: entity.address,
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
        'address': address,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
