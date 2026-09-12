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

import '../enums/capex_request_status.dart';

/// A Capital Expenditure Request — the club's paper CER form, digitised.
///
/// All cost fields are GST-inclusive in cents, matching the source form
/// which does not split out a GST component.
class CapexRequest {
  /// Unique identifier (UUID v4).
  final String id;

  /// Organisation identifier from Auth0.
  final String entityId;

  /// Human-readable request number — the business key (e.g. "CER 26-012").
  final String requestNo;

  /// The date the request was prepared.
  final DateTime requestDate;

  /// Name of the member who prepared the request.
  final String preparedByName;

  /// Short description of what is being requested.
  final String description;

  /// Asset Details — what is being requested.
  final String whatIsRequested;

  /// Asset Details — what need or benefit is met by making this purchase.
  final String needOrBenefit;

  /// Asset Details — alternatives or options considered; null if none noted.
  final String? alternativesConsidered;

  /// Expenditure Details — purchase cost of the asset, GST-inclusive, in cents.
  final int purchaseCostCents;

  /// Expenditure Details — ongoing service costs (consumables, maintenance
  /// spares etc), GST-inclusive, in cents; null if none.
  final int? ongoingCostsCents;

  /// Expenditure Details — other additional costs (transport, installation,
  /// training etc), GST-inclusive, in cents; null if none.
  final int? otherCostsCents;

  /// Free-text remarks for costs that aren't a dollar figure (e.g.
  /// "Installation and setup to be done by members").
  final String? costNotes;

  /// Total amount being requested, GST-inclusive, in cents. Stored rather
  /// than derived — the form gives it its own line and it need not equal
  /// the sum of the individual cost fields.
  final int totalAmountCents;

  /// Number of written quotes received; null if not recorded.
  final int? quotesReceivedCount;

  /// Decision status.
  final CapexRequestStatus status;

  /// Name of the person who approved or rejected the request; null while pending.
  final String? decisionByName;

  /// Timestamp of the approval/rejection decision; null while pending.
  final DateTime? decisionAt;

  /// Notes recorded with the decision; null if none.
  final String? decisionNotes;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const CapexRequest({
    required this.id,
    required this.entityId,
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
    this.status = CapexRequestStatus.pending,
    this.decisionByName,
    this.decisionAt,
    this.decisionNotes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isPending => status == CapexRequestStatus.pending;
}
