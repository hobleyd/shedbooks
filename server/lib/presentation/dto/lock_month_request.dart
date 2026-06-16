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

/// Parsed request body for POST /locked-months.
class LockMonthRequest {
  final String monthYear;
  final String bankAccountId;

  /// When true, the server copies the most recent prior closing balance to the
  /// last day of [monthYear]. Intended for term-deposit accounts that have no
  /// monthly statement.
  final bool carryOverBalance;

  const LockMonthRequest({
    required this.monthYear,
    required this.bankAccountId,
    this.carryOverBalance = false,
  });

  factory LockMonthRequest.fromJson(Map<String, dynamic> json) {
    final monthYear = json['monthYear'];
    if (monthYear is! String || monthYear.isEmpty) {
      throw const FormatException('monthYear is required');
    }
    final bankAccountId = json['bankAccountId'];
    if (bankAccountId is! String || bankAccountId.isEmpty) {
      throw const FormatException('bankAccountId is required');
    }
    return LockMonthRequest(
      monthYear: monthYear,
      bankAccountId: bankAccountId,
      carryOverBalance: json['carryOverBalance'] as bool? ?? false,
    );
  }
}
