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

/// A GST rate entry returned from the API.
class GstRateEntry {
  final String id;
  final double rate; // decimal fraction, e.g. 0.1 = 10%
  final DateTime effectiveFrom;

  const GstRateEntry({
    required this.id,
    required this.rate,
    required this.effectiveFrom,
  });

  factory GstRateEntry.fromJson(Map<String, dynamic> json) {
    return GstRateEntry(
      id: json['id'] as String,
      rate: (json['rate'] as num).toDouble(),
      effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
    );
  }
}
