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

/// Deserialised request body for PUT /capex-requests/:id/executed-date.
///
/// [executedDate] is null to clear a previously-recorded executed date.
class SetCapexRequestExecutedDateRequest {
  final DateTime? executedDate;

  const SetCapexRequestExecutedDateRequest({this.executedDate});

  factory SetCapexRequestExecutedDateRequest.fromJson(Map<String, dynamic> json) {
    final raw = json['executedDate'];
    if (raw == null) return const SetCapexRequestExecutedDateRequest();
    if (raw is! String) {
      throw const FormatException('executedDate must be a date string or null');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw const FormatException('executedDate must be a valid date string');
    }
    return SetCapexRequestExecutedDateRequest(executedDate: parsed);
  }
}
