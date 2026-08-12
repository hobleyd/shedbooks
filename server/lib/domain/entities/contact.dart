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

/// Classifies whether a contact is an individual or a business entity.
enum ContactType { person, company }

/// A contact — either a person or a company — that can appear on transactions.
class Contact {
  /// Unique identifier (UUID v4).
  final String id;

  /// Display name of the contact.
  final String name;

  /// Whether this is a person or a company.
  final ContactType contactType;

  /// Whether the contact is registered for GST.
  /// Always false for [ContactType.person] — enforced in the application layer.
  final bool gstRegistered;

  /// Australian Business Number (11 digits). Required for [ContactType.company],
  /// always null for [ContactType.person].
  final String? abn;

  /// Bank State Branch code (6 digits) for ABA payments.
  final String? bsb;

  /// Bank account number (6-10 digits) for ABA payments.
  final String? accountNumber;

  /// Multi-line postal/billing address, used on invoices raised against this contact.
  final String? address;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const Contact({
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
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
}
