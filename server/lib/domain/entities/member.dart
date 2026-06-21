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

/// A club member record.
///
/// [membershipStatus] is stored verbatim from source data and may be:
/// - A year string (e.g. `"2026"`) — paid up to that year.
/// - `"FLM"` — Full Life Member.
/// - `"GN 2024"`, `"Guest"` — guest/non-member statuses treated as lapsed.
/// - `null` — unknown status.
class Member {
  /// Unique identifier (UUID v4).
  final String id;

  /// Organisation identifier from Auth0.
  final String entityId;

  /// Given name(s).
  final String firstName;

  /// Family name.
  final String lastName;

  /// Date the member first joined the club.
  final DateTime? dateJoined;

  /// Raw membership status string as stored in source data.
  final String? membershipStatus;

  /// Street address.
  final String? streetAddress;

  /// PO Box.
  final String? poBox;

  /// Email address.
  final String? email;

  /// Phone number(s).
  final String? phone;

  /// Date of birth.
  final DateTime? dateOfBirth;

  /// Emergency contact person's name.
  final String? emergencyContactName;

  /// Emergency contact phone number.
  final String? emergencyContactPhone;

  /// Date of woodworking induction.
  final DateTime? woodworkingInduction;

  /// Date of metalworking induction.
  final DateTime? metalworkingInduction;

  /// Date gym waiver was signed.
  final DateTime? gymWaiver;

  /// CardDAV ETag — changes on every update to drive sync.
  final String etag;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const Member({
    required this.id,
    required this.entityId,
    required this.firstName,
    required this.lastName,
    this.dateJoined,
    this.membershipStatus,
    this.streetAddress,
    this.poBox,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.woodworkingInduction,
    this.metalworkingInduction,
    this.gymWaiver,
    required this.etag,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Returns the display name as "firstName lastName" (or just whichever is non-empty).
  String get displayName {
    if (firstName.isEmpty) return lastName;
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }

  /// Returns true when the record has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  /// Returns true when status is `"FLM"` (Full Life Member).
  bool get isLifeMember => membershipStatus == 'FLM';

  /// Returns true when status is a year equal to or after [year].
  bool isCurrentFor(int year) {
    final parsed = int.tryParse(membershipStatus ?? '');
    return parsed != null && parsed >= year;
  }
}
