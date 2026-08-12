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

import '../../domain/entities/contact.dart';

/// Deserialised request body for POST /contacts.
class CreateContactRequest {
  final String name;
  final ContactType contactType;
  final bool gstRegistered;
  final String? abn;
  final String? bsb;
  final String? accountNumber;
  final String? address;

  const CreateContactRequest({
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
    this.bsb,
    this.accountNumber,
    this.address,
  });

  factory CreateContactRequest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final contactTypeRaw = json['contactType'];
    final gstRegistered = json['gstRegistered'];
    final abn = json['abn'];
    final bsb = json['bsb'];
    final accountNumber = json['accountNumber'];
    final address = json['address'];

    if (name is! String) throw const FormatException('name must be a string');
    if (contactTypeRaw is! String) {
      throw const FormatException('contactType must be a string');
    }
    if (gstRegistered is! bool) {
      throw const FormatException('gstRegistered must be a boolean');
    }
    if (abn != null && abn is! String) {
      throw const FormatException('abn must be a string');
    }
    if (bsb != null && bsb is! String) {
      throw const FormatException('bsb must be a string');
    }
    if (accountNumber != null && accountNumber is! String) {
      throw const FormatException('accountNumber must be a string');
    }
    if (address != null && address is! String) {
      throw const FormatException('address must be a string');
    }

    final ContactType contactType;
    try {
      contactType = ContactType.values.byName(contactTypeRaw);
    } on ArgumentError {
      throw FormatException(
        'contactType must be one of: ${ContactType.values.map((e) => e.name).join(', ')}',
      );
    }

    return CreateContactRequest(
      name: name,
      contactType: contactType,
      gstRegistered: gstRegistered,
      abn: abn as String?,
      bsb: bsb as String?,
      accountNumber: accountNumber as String?,
      address: address as String?,
    );
  }
}
