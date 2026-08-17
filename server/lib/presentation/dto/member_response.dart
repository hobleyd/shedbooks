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

import 'dart:convert';

import '../../domain/entities/member.dart';

/// JSON response shape for a member.
class MemberResponse {
  final String id;
  final String firstName;
  final String lastName;
  final String? dateJoined;
  final String? membershipStatus;
  final String? streetAddress;
  final String? poBox;
  final String? email;
  final String? phone;
  final String? dateOfBirth;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? woodworkingInduction;
  final String? metalworkingInduction;
  final String? gymWaiver;
  final String? o365SyncedAt;
  final String? o365SyncFailedAt;
  final String etag;
  final String createdAt;
  final String updatedAt;

  const MemberResponse({
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
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemberResponse.fromEntity(Member entity) {
    return MemberResponse(
      id: entity.id,
      firstName: entity.firstName,
      lastName: entity.lastName,
      dateJoined: entity.dateJoined?.toIso8601String().substring(0, 10),
      membershipStatus: entity.membershipStatus,
      streetAddress: entity.streetAddress,
      poBox: entity.poBox,
      email: entity.email,
      phone: entity.phone,
      dateOfBirth: entity.dateOfBirth?.toIso8601String().substring(0, 10),
      emergencyContactName: entity.emergencyContactName,
      emergencyContactPhone: entity.emergencyContactPhone,
      woodworkingInduction:
          entity.woodworkingInduction?.toIso8601String().substring(0, 10),
      metalworkingInduction:
          entity.metalworkingInduction?.toIso8601String().substring(0, 10),
      gymWaiver: entity.gymWaiver?.toIso8601String().substring(0, 10),
      o365SyncedAt: entity.o365SyncedAt?.toUtc().toIso8601String(),
      o365SyncFailedAt: entity.o365SyncFailedAt?.toUtc().toIso8601String(),
      etag: entity.etag,
      createdAt: entity.createdAt.toUtc().toIso8601String(),
      updatedAt: entity.updatedAt.toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
        'o365SyncedAt': o365SyncedAt,
        'o365SyncFailedAt': o365SyncFailedAt,
        'etag': etag,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
