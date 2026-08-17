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

/// A member entry returned from the API.
class MemberEntry {
  final String id;
  final String firstName;
  final String lastName;

  /// Date joined in ISO 8601 date format (YYYY-MM-DD), or null.
  final String? dateJoined;

  /// Raw membership status: year string (e.g. "2026"), "FLM", "Guest", etc.
  final String? membershipStatus;

  final String? streetAddress;
  final String? poBox;
  final String? email;
  final String? phone;

  /// Date of birth in ISO 8601 date format (YYYY-MM-DD), or null.
  final String? dateOfBirth;

  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? woodworkingInduction;
  final String? metalworkingInduction;
  final String? gymWaiver;

  /// Timestamp of the last successful O365 GAL sync, or null if this
  /// member has never been synced.
  final DateTime? o365SyncedAt;

  /// Timestamp of the most recent failed O365 GAL sync attempt, or null
  /// if the last attempt (if any) succeeded. Cleared server-side on the
  /// next success, so a non-null value always means the most recent
  /// attempt — not necessarily the only one — failed.
  final DateTime? o365SyncFailedAt;

  /// CardDAV ETag — changes on every server-side update.
  final String etag;

  const MemberEntry({
    required this.id,
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
    this.o365SyncedAt,
    this.o365SyncFailedAt,
    required this.etag,
  });

  String get displayName {
    if (firstName.isEmpty) return lastName;
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }

  factory MemberEntry.fromJson(Map<String, dynamic> json) {
    return MemberEntry(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      dateJoined: json['dateJoined'] as String?,
      membershipStatus: json['membershipStatus'] as String?,
      streetAddress: json['streetAddress'] as String?,
      poBox: json['poBox'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      woodworkingInduction: json['woodworkingInduction'] as String?,
      metalworkingInduction: json['metalworkingInduction'] as String?,
      gymWaiver: json['gymWaiver'] as String?,
      o365SyncedAt: json['o365SyncedAt'] != null
          ? DateTime.parse(json['o365SyncedAt'] as String)
          : null,
      o365SyncFailedAt: json['o365SyncFailedAt'] != null
          ? DateTime.parse(json['o365SyncFailedAt'] as String)
          : null,
      etag: json['etag'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'dateJoined': dateJoined,
        'membershipStatus': membershipStatus,
        'streetAddress': streetAddress,
        'poBox': poBox,
        'email': email,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'woodworkingInduction': woodworkingInduction,
        'metalworkingInduction': metalworkingInduction,
        'gymWaiver': gymWaiver,
      };
}
