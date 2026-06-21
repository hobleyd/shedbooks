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

/// Deserialised request body for POST /members.
class CreateMemberRequest {
  final String firstName;
  final String lastName;
  final DateTime? dateJoined;
  final String? membershipStatus;
  final String? streetAddress;
  final String? poBox;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? woodworkingInduction;
  final DateTime? metalworkingInduction;
  final DateTime? gymWaiver;

  const CreateMemberRequest({
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
  });

  factory CreateMemberRequest.fromJson(Map<String, dynamic> json) {
    return CreateMemberRequest(
      firstName: _optionalString(json, 'firstName') ?? '',
      lastName: _requireString(json, 'lastName'),
      dateJoined: _optionalDate(json, 'dateJoined'),
      membershipStatus: _optionalString(json, 'membershipStatus'),
      streetAddress: _optionalString(json, 'streetAddress'),
      poBox: _optionalString(json, 'poBox'),
      email: _optionalString(json, 'email'),
      phone: _optionalString(json, 'phone'),
      dateOfBirth: _optionalDate(json, 'dateOfBirth'),
      emergencyContactName: _optionalString(json, 'emergencyContactName'),
      emergencyContactPhone: _optionalString(json, 'emergencyContactPhone'),
      woodworkingInduction: _optionalDate(json, 'woodworkingInduction'),
      metalworkingInduction: _optionalDate(json, 'metalworkingInduction'),
      gymWaiver: _optionalDate(json, 'gymWaiver'),
    );
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is! String) throw FormatException('$key must be a string');
    return v;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String) throw FormatException('$key must be a string');
    return v;
  }

  static DateTime? _optionalDate(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String) throw FormatException('$key must be a date string');
    try {
      final dt = DateTime.parse(v);
      return DateTime.utc(dt.year, dt.month, dt.day);
    } catch (_) {
      throw FormatException('$key must be a valid date (YYYY-MM-DD)');
    }
  }
}
