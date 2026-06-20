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

import '../entities/member.dart';

/// Contract for member persistence.
abstract interface class IMemberRepository {
  /// Creates a new member and returns the persisted entity.
  Future<Member> create({
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
    String? emergencyContact,
    DateTime? woodworkingInduction,
    DateTime? metalworkingInduction,
    DateTime? gymWaiver,
  });

  /// Returns the member with [id] scoped to [entityId], or null if not found.
  Future<Member?> findById(String id, {required String entityId});

  /// Returns all active members for [entityId], ordered by last name then first name.
  Future<List<Member>> findAll({required String entityId});

  /// Updates the member with [id] and returns the updated entity.
  ///
  /// Throws [StateError] if the member does not exist or belongs to a different entity.
  Future<Member> update({
    required String id,
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
    String? emergencyContact,
    DateTime? woodworkingInduction,
    DateTime? metalworkingInduction,
    DateTime? gymWaiver,
  });

  /// Soft-deletes the member with [id].
  ///
  /// Throws [StateError] if the member does not exist or belongs to a different entity.
  Future<void> delete(String id, {required String entityId});

  /// Bulk-inserts a list of members within a single transaction.
  ///
  /// Returns the list of created members in insertion order.
  Future<List<Member>> importMany({
    required String entityId,
    required List<MemberImportData> members,
  });
}

/// Data transfer object for bulk member import.
class MemberImportData {
  final String firstName;
  final String lastName;
  final DateTime? dateJoined;
  final String? membershipStatus;
  final String? streetAddress;
  final String? poBox;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? emergencyContact;
  final DateTime? woodworkingInduction;
  final DateTime? metalworkingInduction;
  final DateTime? gymWaiver;

  const MemberImportData({
    required this.firstName,
    required this.lastName,
    this.dateJoined,
    this.membershipStatus,
    this.streetAddress,
    this.poBox,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.emergencyContact,
    this.woodworkingInduction,
    this.metalworkingInduction,
    this.gymWaiver,
  });
}
