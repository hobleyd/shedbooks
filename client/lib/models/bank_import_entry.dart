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

/// A bank statement row previously actioned during an import session.
class BankImportEntry {
  final String processDate;
  final String description;
  final int amountCents;
  final bool isDebit;

  const BankImportEntry({
    required this.processDate,
    required this.description,
    required this.amountCents,
    required this.isDebit,
  });

  factory BankImportEntry.fromJson(Map<String, dynamic> json) =>
      BankImportEntry(
        processDate: json['processDate'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        isDebit: json['isDebit'] as bool,
      );

  /// Key used for O(1) deduplication lookups.
  String get dedupKey => '$processDate\x00${isDebit ? 1 : 0}\x00$amountCents\x00$description';
}
