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

/// A closing bank balance record returned by the server.
class ClosingBankBalanceEntry {
  final String id;
  final String bankAccountId;
  final String balanceDate;
  final int balanceCents;
  final String statementPeriod;
  final DateTime createdAt;

  const ClosingBankBalanceEntry({
    required this.id,
    required this.bankAccountId,
    required this.balanceDate,
    required this.balanceCents,
    required this.statementPeriod,
    required this.createdAt,
  });

  factory ClosingBankBalanceEntry.fromJson(Map<String, dynamic> json) =>
      ClosingBankBalanceEntry(
        id: json['id'] as String,
        bankAccountId: json['bankAccountId'] as String,
        balanceDate: json['balanceDate'] as String,
        balanceCents: json['balanceCents'] as int,
        statementPeriod: json['statementPeriod'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
