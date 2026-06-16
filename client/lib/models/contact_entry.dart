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

/// Contact type classification.
enum ContactType { person, company }

/// A contact entry returned from the API.
class ContactEntry {
  final String id;
  final String name;
  final ContactType contactType;
  final bool gstRegistered;

  /// ABN (11 digits). Only present for company contacts.
  final String? abn;

  /// BSB (6 digits) for ABA payments.
  final String? bsb;

  /// Account number (6-10 digits) for ABA payments.
  final String? accountNumber;

  const ContactEntry({
    required this.id,
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
    this.bsb,
    this.accountNumber,
  });

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    return ContactEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      contactType: ContactType.values.byName(json['contactType'] as String),
      gstRegistered: json['gstRegistered'] as bool,
      abn: json['abn'] as String?,
      bsb: json['bsb'] as String?,
      accountNumber: json['accountNumber'] as String?,
    );
  }
}
