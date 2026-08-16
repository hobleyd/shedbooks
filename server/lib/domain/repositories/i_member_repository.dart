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
    String? emergencyContactName,
    String? emergencyContactPhone,
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
    String? emergencyContactName,
    String? emergencyContactPhone,
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

  /// Returns up to [limit] active members that need to be pushed to O365:
  /// never synced, or edited since their last successful sync.
  Future<List<Member>> findPendingO365Sync({
    required String entityId,
    required int limit,
  });

  /// Counts active members that need to be pushed to O365.
  Future<int> countPendingO365Sync({required String entityId});

  /// Records a successful O365 push. Deliberately touches only the two
  /// sync-tracking columns — it must NOT bump `updated_at` or `etag`, or
  /// every sync run would re-dirty the row (making it "pending" again)
  /// and every CardDAV client would see a spurious change.
  Future<void> markO365Synced({
    required String id,
    required String entityId,
    required String o365ContactId,
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
  final String? emergencyContactName;
  final String? emergencyContactPhone;
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
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.woodworkingInduction,
    this.metalworkingInduction,
    this.gymWaiver,
  });
}
