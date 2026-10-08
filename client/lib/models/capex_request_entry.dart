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

/// A Capital Expenditure Request, as returned by the /capex-requests API.
class CapexRequestEntry {
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

  /// What the purchase actually cost (GST-inclusive), recorded with the
  /// executed date; null until known.
  final int? actualSpentCents;
  final String? invoiceId;
  final String? invoiceNumber;

  /// GST-inclusive total of the linked invoice, comparable with
  /// [totalAmountCents]; null when no invoice is linked.
  final int? invoiceTotalCents;

  const CapexRequestEntry({
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
    this.actualSpentCents,
    this.invoiceId,
    this.invoiceNumber,
    this.invoiceTotalCents,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  /// The amount spent on this request: [actualSpentCents] once recorded,
  /// otherwise the requested [totalAmountCents].
  int get amountSpentCents => actualSpentCents ?? totalAmountCents;

  /// Linked invoice total minus [amountSpentCents]: positive when the
  /// invoice more than covers the spend, negative when it falls short. Null
  /// when no invoice is linked.
  int? get invoiceDeltaCents =>
      invoiceTotalCents == null ? null : invoiceTotalCents! - amountSpentCents;

  factory CapexRequestEntry.fromJson(Map<String, dynamic> json) {
    return CapexRequestEntry(
      id: json['id'] as String,
      requestNo: json['requestNo'] as String,
      requestDate: json['requestDate'] as String,
      preparedByName: json['preparedByName'] as String,
      description: json['description'] as String,
      whatIsRequested: json['whatIsRequested'] as String,
      needOrBenefit: json['needOrBenefit'] as String,
      alternativesConsidered: json['alternativesConsidered'] as String?,
      purchaseCostCents: json['purchaseCostCents'] as int,
      ongoingCostsCents: json['ongoingCostsCents'] as int?,
      otherCostsCents: json['otherCostsCents'] as int?,
      costNotes: json['costNotes'] as String?,
      totalAmountCents: json['totalAmountCents'] as int,
      quotesReceivedCount: json['quotesReceivedCount'] as int?,
      status: json['status'] as String,
      decisionByName: json['decisionByName'] as String?,
      decisionAt: json['decisionAt'] as String?,
      decisionNotes: json['decisionNotes'] as String?,
      executedDate: json['executedDate'] as String?,
      actualSpentCents: json['actualSpentCents'] as int?,
      invoiceId: json['invoiceId'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      invoiceTotalCents: json['invoiceTotalCents'] as int?,
    );
  }
}
