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

import '../../domain/exceptions/capex_request_exception.dart';

/// Validates the fields shared by create and update, shared here to avoid
/// the two use cases drifting apart.
///
/// Throws [CapexRequestValidationException] on the first failing rule.
void validateCapexRequestFields({
  required String requestNo,
  required String preparedByName,
  required String description,
  required String whatIsRequested,
  required String needOrBenefit,
  required int purchaseCostCents,
  int? ongoingCostsCents,
  int? otherCostsCents,
  required int totalAmountCents,
  int? quotesReceivedCount,
}) {
  if (requestNo.trim().isEmpty) {
    throw const CapexRequestValidationException('Request number must not be empty');
  }
  if (preparedByName.trim().isEmpty) {
    throw const CapexRequestValidationException('Prepared by name must not be empty');
  }
  if (description.trim().isEmpty) {
    throw const CapexRequestValidationException('Description must not be empty');
  }
  if (whatIsRequested.trim().isEmpty) {
    throw const CapexRequestValidationException('What is being requested must not be empty');
  }
  if (needOrBenefit.trim().isEmpty) {
    throw const CapexRequestValidationException(
        'What need or benefit is being met must not be empty');
  }
  if (purchaseCostCents < 0) {
    throw const CapexRequestValidationException('Purchase cost must not be negative');
  }
  if (ongoingCostsCents != null && ongoingCostsCents < 0) {
    throw const CapexRequestValidationException('Ongoing service costs must not be negative');
  }
  if (otherCostsCents != null && otherCostsCents < 0) {
    throw const CapexRequestValidationException('Other additional costs must not be negative');
  }
  if (totalAmountCents < 0) {
    throw const CapexRequestValidationException('Total amount must not be negative');
  }
  if (quotesReceivedCount != null && quotesReceivedCount < 0) {
    throw const CapexRequestValidationException('Number of quotes received must not be negative');
  }
}
