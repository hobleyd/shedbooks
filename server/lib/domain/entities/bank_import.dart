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

/// A bank statement row that has been actioned during a CBA import session.
class BankImport {
  final String id;
  final String entityId;

  /// ISO-8601 date string (YYYY-MM-DD) from the bank statement Process Date column.
  final String processDate;

  final String description;
  final int amountCents;
  final bool isDebit;
  final DateTime importedAt;

  const BankImport({
    required this.id,
    required this.entityId,
    required this.processDate,
    required this.description,
    required this.amountCents,
    required this.isDebit,
    required this.importedAt,
  });
}
