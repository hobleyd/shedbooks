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

/// Deserialised request body for POST /gst-rates.
class CreateGstRateRequest {
  final double rate;
  final DateTime effectiveFrom;

  const CreateGstRateRequest({required this.rate, required this.effectiveFrom});

  factory CreateGstRateRequest.fromJson(Map<String, dynamic> json) {
    final rate = json['rate'];
    final effectiveFromRaw = json['effectiveFrom'];

    if (rate is! num) throw const FormatException('rate must be a number');
    if (effectiveFromRaw is! String) {
      throw const FormatException('effectiveFrom must be an ISO 8601 date string');
    }

    final DateTime effectiveFrom;
    try {
      effectiveFrom = DateTime.parse(effectiveFromRaw).toUtc();
    } on FormatException {
      throw const FormatException('effectiveFrom must be a valid ISO 8601 date');
    }

    return CreateGstRateRequest(
      rate: rate.toDouble(),
      effectiveFrom: effectiveFrom,
    );
  }
}
