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

import '../../domain/repositories/i_member_repository.dart';

/// Deserialised request body for POST /members/import.
///
/// Accepts a JSON array of member objects, each using the same shape as
/// [CreateMemberRequest].
class ImportMembersRequest {
  final List<MemberImportData> members;

  const ImportMembersRequest(this.members);

  factory ImportMembersRequest.fromJson(List<dynamic> json) {
    return ImportMembersRequest(
      json.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value;
        if (item is! Map<String, dynamic>) {
          throw FormatException('Item at index $i must be an object');
        }
        return _parseItem(i, item);
      }).toList(),
    );
  }

  static MemberImportData _parseItem(int index, Map<String, dynamic> json) {
    // Accept either firstName/lastName or legacy name ("Last First(s)" format).
    String firstName;
    String lastName;
    if (json.containsKey('lastName')) {
      lastName = _optionalString(json, 'lastName') ?? '';
      firstName = _optionalString(json, 'firstName') ?? '';
    } else {
      final name = json['name'];
      if (name is! String || name.trim().isEmpty) {
        throw FormatException('Item $index: name must be a non-empty string');
      }
      final trimmed = name.trim();
      if (trimmed.contains(',')) {
        final comma = trimmed.indexOf(',');
        lastName = trimmed.substring(0, comma).trim();
        firstName = trimmed.substring(comma + 1).trim();
      } else if (trimmed.contains(' ')) {
        final space = trimmed.indexOf(' ');
        lastName = trimmed.substring(0, space).trim();
        firstName = trimmed.substring(space + 1).trim();
      } else {
        lastName = trimmed;
        firstName = '';
      }
    }
    if (lastName.isEmpty) {
      throw FormatException('Item $index: last name must be non-empty');
    }
    return MemberImportData(
      firstName: firstName,
      lastName: lastName,
      dateJoined: _optionalDate(json, 'dateJoined', index),
      membershipStatus: _optionalString(json, 'membershipStatus'),
      streetAddress: _optionalString(json, 'streetAddress'),
      poBox: _optionalString(json, 'poBox'),
      email: _optionalString(json, 'email'),
      phone: _optionalString(json, 'phone'),
      dateOfBirth: _optionalDate(json, 'dateOfBirth', index),
      emergencyContactName: _optionalString(json, 'emergencyContactName') ??
          _splitEmergency(_optionalString(json, 'emergencyContact')).$1,
      emergencyContactPhone: _optionalString(json, 'emergencyContactPhone') ??
          _splitEmergency(_optionalString(json, 'emergencyContact')).$2,
      woodworkingInduction: _optionalDate(json, 'woodworkingInduction', index),
      metalworkingInduction: _optionalDate(json, 'metalworkingInduction', index),
      gymWaiver: _optionalDate(json, 'gymWaiver', index),
    );
  }

  /// Splits a legacy combined emergency-contact string into (name, phone).
  ///
  /// Detects a 10-digit Australian phone number (\b0\d{9}\b) and extracts it;
  /// the remainder (whitespace collapsed) becomes the name.
  static (String?, String?) _splitEmergency(String? value) {
    if (value == null) return (null, null);
    final trimmed = value.trim();
    if (trimmed.isEmpty) return (null, null);
    final match = RegExp(r'\b0\d{9}\b').firstMatch(trimmed);
    if (match == null) return (trimmed, null);
    final phone = match.group(0)!;
    final rest = (trimmed.substring(0, match.start).trim() +
            ' ' +
            trimmed.substring(match.end).trim())
        .trim()
        .replaceAll(RegExp(r'\s{2,}'), ' ');
    return (rest.isEmpty ? null : rest, phone);
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final v = json[key];
    return (v is String) ? v : null;
  }

  static DateTime? _optionalDate(
      Map<String, dynamic> json, String key, int index) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String) return null;
    try {
      final dt = DateTime.parse(v);
      return DateTime.utc(dt.year, dt.month, dt.day);
    } catch (_) {
      throw FormatException('Item $index: $key must be a valid date');
    }
  }
}
