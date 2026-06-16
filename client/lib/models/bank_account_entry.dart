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

/// The type of bank account.
enum BankAccountType { transaction, savings, termDeposit, cash }

/// A bank account returned from the API.
class BankAccountEntry {
  final String id;
  final String bankName;
  final String accountName;
  final String bsb;
  final String accountNumber;
  final BankAccountType accountType;
  final String currency;
  final bool isSystem;
  final int sortOrder;

  const BankAccountEntry({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
    required this.accountType,
    required this.currency,
    required this.isSystem,
    required this.sortOrder,
  });

  factory BankAccountEntry.fromJson(Map<String, dynamic> json) =>
      BankAccountEntry(
        id: json['id'] as String,
        bankName: json['bankName'] as String,
        accountName: json['accountName'] as String,
        bsb: json['bsb'] as String,
        accountNumber: json['accountNumber'] as String,
        accountType: switch (json['accountType'] as String) {
          'savings' => BankAccountType.savings,
          'termDeposit' => BankAccountType.termDeposit,
          'cash' => BankAccountType.cash,
          _ => BankAccountType.transaction,
        },
        currency: json['currency'] as String,
        isSystem: json['isSystem'] as bool? ?? false,
        sortOrder: json['sortOrder'] as int? ?? 0,
      );

  /// BSB formatted as XXX-XXX for display.
  String get bsbFormatted =>
      bsb.length == 6 ? '${bsb.substring(0, 3)}-${bsb.substring(3)}' : bsb;

  String get accountTypeLabel => switch (accountType) {
        BankAccountType.transaction => 'Transaction',
        BankAccountType.savings => 'Savings',
        BankAccountType.termDeposit => 'Term Deposit',
        BankAccountType.cash => 'Cash',
      };
}
