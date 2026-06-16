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

/// Parsed body for POST /bank-imports.
class SaveBankImportsRequest {
  final List<({String processDate, String description, int amountCents, bool isDebit})> rows;

  const SaveBankImportsRequest({required this.rows});

  factory SaveBankImportsRequest.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'];
    if (raw is! List) throw const FormatException('"rows" must be an array');
    final rows = raw.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('each row must be an object');
      }
      final processDate = item['processDate'];
      final description = item['description'];
      final amountCents = item['amountCents'];
      final isDebit = item['isDebit'];
      if (processDate is! String) {
        throw const FormatException('"processDate" must be a string');
      }
      if (description is! String) {
        throw const FormatException('"description" must be a string');
      }
      if (amountCents is! int) {
        throw const FormatException('"amountCents" must be an integer');
      }
      if (isDebit is! bool) {
        throw const FormatException('"isDebit" must be a boolean');
      }
      return (
        processDate: processDate,
        description: description,
        amountCents: amountCents,
        isDebit: isDebit,
      );
    }).toList();
    return SaveBankImportsRequest(rows: rows);
  }
}
