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

/// Minimal bank account representation used for dropdown selection.
class BankAccountSummary {
  final String id;
  final String accountName;
  final String bankName;
  final String bsb;
  final String accountNumber;

  const BankAccountSummary({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.bsb,
    required this.accountNumber,
  });

  factory BankAccountSummary.fromJson(Map<String, dynamic> json) =>
      BankAccountSummary(
        id: json['id'] as String,
        accountName: json['accountName'] as String,
        bankName: json['bankName'] as String? ?? '',
        bsb: json['bsb'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
      );

  /// BSB formatted as XXX-XXX for display.
  String get bsbFormatted =>
      bsb.length == 6 ? '${bsb.substring(0, 3)}-${bsb.substring(3)}' : bsb;
}
