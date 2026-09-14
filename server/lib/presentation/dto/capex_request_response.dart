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

import '../../domain/entities/capex_request.dart';

/// JSON response shape for a capex request.
class CapexRequestResponse {
  final String id;
  final String requestNo;
  final String requestDate;
  final String preparedByName;
  final String description;
  final String whatIsRequested;
  final String needOrBenefit;
  final String? alternativesConsidered;
  final int purchaseCostCents;
  final int? ongoingCostsCents;
  final int? otherCostsCents;
  final String? costNotes;
  final int totalAmountCents;
  final int? quotesReceivedCount;
  final String status;
  final String? decisionByName;
  final String? decisionAt;
  final String? decisionNotes;
  final String? executedDate;
  final String createdAt;
  final String updatedAt;

  const CapexRequestResponse({
    required this.id,
    required this.requestNo,
    required this.requestDate,
    required this.preparedByName,
    required this.description,
    required this.whatIsRequested,
    required this.needOrBenefit,
    this.alternativesConsidered,
    required this.purchaseCostCents,
    this.ongoingCostsCents,
    this.otherCostsCents,
    this.costNotes,
    required this.totalAmountCents,
    this.quotesReceivedCount,
    required this.status,
    this.decisionByName,
    this.decisionAt,
    this.decisionNotes,
    this.executedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CapexRequestResponse.fromEntity(CapexRequest entity) => CapexRequestResponse(
        id: entity.id,
        requestNo: entity.requestNo,
        requestDate: entity.requestDate.toIso8601String().substring(0, 10),
        preparedByName: entity.preparedByName,
        description: entity.description,
        whatIsRequested: entity.whatIsRequested,
        needOrBenefit: entity.needOrBenefit,
        alternativesConsidered: entity.alternativesConsidered,
        purchaseCostCents: entity.purchaseCostCents,
        ongoingCostsCents: entity.ongoingCostsCents,
        otherCostsCents: entity.otherCostsCents,
        costNotes: entity.costNotes,
        totalAmountCents: entity.totalAmountCents,
        quotesReceivedCount: entity.quotesReceivedCount,
        status: entity.status.name,
        decisionByName: entity.decisionByName,
        decisionAt: entity.decisionAt?.toUtc().toIso8601String(),
        decisionNotes: entity.decisionNotes,
        executedDate: entity.executedDate?.toIso8601String().substring(0, 10),
        createdAt: entity.createdAt.toUtc().toIso8601String(),
        updatedAt: entity.updatedAt.toUtc().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestNo': requestNo,
        'requestDate': requestDate,
        'preparedByName': preparedByName,
        'description': description,
        'whatIsRequested': whatIsRequested,
        'needOrBenefit': needOrBenefit,
        'alternativesConsidered': alternativesConsidered,
        'purchaseCostCents': purchaseCostCents,
        'ongoingCostsCents': ongoingCostsCents,
        'otherCostsCents': otherCostsCents,
        'costNotes': costNotes,
        'totalAmountCents': totalAmountCents,
        'quotesReceivedCount': quotesReceivedCount,
        'status': status,
        'decisionByName': decisionByName,
        'decisionAt': decisionAt,
        'decisionNotes': decisionNotes,
        'executedDate': executedDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String toJsonString() => jsonEncode(toJson());
}
