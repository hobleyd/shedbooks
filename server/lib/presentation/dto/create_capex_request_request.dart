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

/// Deserialised request body for POST /capex-requests and PUT /capex-requests/:id.
class CreateCapexRequestRequest {
  final String requestNo;
  final DateTime requestDate;
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

  const CreateCapexRequestRequest({
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
  });

  factory CreateCapexRequestRequest.fromJson(Map<String, dynamic> json) {
    final requestNo = json['requestNo'];
    if (requestNo is! String || requestNo.trim().isEmpty) {
      throw const FormatException('requestNo must be a non-empty string');
    }
    final requestDateRaw = json['requestDate'];
    if (requestDateRaw is! String) {
      throw const FormatException('requestDate must be a string (YYYY-MM-DD)');
    }
    final requestDate = DateTime.tryParse(requestDateRaw);
    if (requestDate == null) {
      throw const FormatException('requestDate must be a valid date');
    }
    final preparedByName = json['preparedByName'];
    if (preparedByName is! String || preparedByName.trim().isEmpty) {
      throw const FormatException('preparedByName must be a non-empty string');
    }
    final description = json['description'];
    if (description is! String || description.trim().isEmpty) {
      throw const FormatException('description must be a non-empty string');
    }
    final whatIsRequested = json['whatIsRequested'];
    if (whatIsRequested is! String || whatIsRequested.trim().isEmpty) {
      throw const FormatException('whatIsRequested must be a non-empty string');
    }
    final needOrBenefit = json['needOrBenefit'];
    if (needOrBenefit is! String || needOrBenefit.trim().isEmpty) {
      throw const FormatException('needOrBenefit must be a non-empty string');
    }
    final purchaseCostCents = _requiredInt(json, 'purchaseCostCents');
    final totalAmountCents = _requiredInt(json, 'totalAmountCents');

    return CreateCapexRequestRequest(
      requestNo: requestNo,
      requestDate: requestDate,
      preparedByName: preparedByName,
      description: description,
      whatIsRequested: whatIsRequested,
      needOrBenefit: needOrBenefit,
      alternativesConsidered: _optionalString(json, 'alternativesConsidered'),
      purchaseCostCents: purchaseCostCents,
      ongoingCostsCents: _optionalInt(json, 'ongoingCostsCents'),
      otherCostsCents: _optionalInt(json, 'otherCostsCents'),
      costNotes: _optionalString(json, 'costNotes'),
      totalAmountCents: totalAmountCents,
      quotesReceivedCount: _optionalInt(json, 'quotesReceivedCount'),
    );
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final v = _optionalInt(json, key);
    if (v == null) throw FormatException('$key must be a number');
    return v;
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final v = json[key];
    return (v is String) ? v : null;
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
