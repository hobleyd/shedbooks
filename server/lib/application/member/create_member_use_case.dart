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

import 'dart:async';

import '../../domain/entities/member.dart';
import '../../domain/exceptions/member_exception.dart';
import '../../domain/repositories/i_member_repository.dart';
import '../o365/member_o365_auto_sync.dart';

/// Creates a new club member.
class CreateMemberUseCase {
  final IMemberRepository _repository;
  final MemberO365AutoSync? _o365AutoSync;

  const CreateMemberUseCase(this._repository, [this._o365AutoSync]);

  /// Validates [lastName] is non-empty, then persists and returns the new [Member].
  Future<Member> execute({
    required String entityId,
    required String firstName,
    required String lastName,
    DateTime? dateJoined,
    String? membershipStatus,
    String? streetAddress,
    String? poBox,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? woodworkingInduction,
    DateTime? metalworkingInduction,
    DateTime? gymWaiver,
  }) async {
    if (lastName.trim().isEmpty) {
      throw const MemberValidationException('Last name must not be empty');
    }
    final member = await _repository.create(
      entityId: entityId,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      dateJoined: dateJoined,
      membershipStatus: membershipStatus?.trim().isEmpty == true
          ? null
          : membershipStatus?.trim(),
      streetAddress:
          streetAddress?.trim().isEmpty == true ? null : streetAddress?.trim(),
      poBox: poBox?.trim().isEmpty == true ? null : poBox?.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      dateOfBirth: dateOfBirth,
      emergencyContactName: emergencyContactName?.trim().isEmpty == true
          ? null
          : emergencyContactName?.trim(),
      emergencyContactPhone: emergencyContactPhone?.trim().isEmpty == true
          ? null
          : emergencyContactPhone?.trim(),
      woodworkingInduction: woodworkingInduction,
      metalworkingInduction: metalworkingInduction,
      gymWaiver: gymWaiver,
    );
    // Fire-and-forget: an Exchange Online session can take 10-20s and must
    // never block the member-save response. See MemberO365AutoSync.
    unawaited(_o365AutoSync?.maybeSync(entityId, member));
    return member;
  }
}
