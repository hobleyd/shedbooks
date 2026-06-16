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

/// A closing bank balance record for a given bank account and statement period.
class ClosingBankBalance {
  final String id;
  final String entityId;
  final String bankAccountId;

  /// Last day of the statement period (ISO date string, e.g. "2026-04-30").
  final String balanceDate;

  /// Closing balance in cents (positive = credit).
  final int balanceCents;

  /// Human-readable statement period, e.g. "1 Apr 2026 - 30 Apr 2026".
  final String statementPeriod;

  final DateTime createdAt;

  const ClosingBankBalance({
    required this.id,
    required this.entityId,
    required this.bankAccountId,
    required this.balanceDate,
    required this.balanceCents,
    required this.statementPeriod,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityId': entityId,
        'bankAccountId': bankAccountId,
        'balanceDate': balanceDate,
        'balanceCents': balanceCents,
        'statementPeriod': statementPeriod,
        'createdAt': createdAt.toIso8601String(),
      };
}
