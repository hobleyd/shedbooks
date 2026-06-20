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

import '../../domain/entities/member.dart';
import '../../domain/exceptions/member_exception.dart';
import '../../domain/repositories/i_member_repository.dart';

/// Bulk-imports a list of members in a single transaction.
class ImportMembersUseCase {
  final IMemberRepository _repository;

  const ImportMembersUseCase(this._repository);

  /// Validates all [members] then bulk-inserts them for [entityId].
  ///
  /// Throws [MemberValidationException] if any member has an empty last name.
  /// All records are inserted within a single database transaction; if any
  /// insert fails the entire batch is rolled back.
  Future<List<Member>> execute({
    required String entityId,
    required List<MemberImportData> members,
  }) async {
    if (members.isEmpty) return [];
    for (final m in members) {
      if (m.lastName.trim().isEmpty) {
        throw const MemberValidationException(
            'All imported members must have a non-empty last name');
      }
    }
    final normalised = members
        .map((m) => MemberImportData(
              firstName: m.firstName.trim(),
              lastName: m.lastName.trim(),
              dateJoined: m.dateJoined,
              membershipStatus: m.membershipStatus?.trim().isEmpty == true
                  ? null
                  : m.membershipStatus?.trim(),
              streetAddress: m.streetAddress?.trim().isEmpty == true
                  ? null
                  : m.streetAddress?.trim(),
              poBox: m.poBox?.trim().isEmpty == true ? null : m.poBox?.trim(),
              email:
                  m.email?.trim().isEmpty == true ? null : m.email?.trim(),
              phone:
                  m.phone?.trim().isEmpty == true ? null : m.phone?.trim(),
              dateOfBirth: m.dateOfBirth,
              emergencyContact: m.emergencyContact?.trim().isEmpty == true
                  ? null
                  : m.emergencyContact?.trim(),
            ))
        .toList();
    return _repository.importMany(entityId: entityId, members: normalised);
  }
}
