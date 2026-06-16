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

import '../../domain/entities/bank_account.dart';

/// Request DTO for creating a bank account.
class CreateBankAccountRequest {
  final String bankName;
  final String accountName;
  final String bsb;
  final String accountNumber;
  final BankAccountType accountType;
  final String currency;

  const CreateBankAccountRequest({
    required this.bankName,
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
    required this.accountType,
    required this.currency,
  });

  factory CreateBankAccountRequest.fromJson(Map<String, dynamic> json) {
    final bankName = json['bankName'];
    final accountName = json['accountName'];
    final bsb = json['bsb'];
    final accountNumber = json['accountNumber'];
    final accountType = json['accountType'];
    final currency = json['currency'] ?? 'AUD';

    if (bankName is! String) throw const FormatException('bankName must be a string');
    if (accountName is! String) throw const FormatException('accountName must be a string');
    if (bsb is! String) throw const FormatException('bsb must be a string');
    if (accountNumber is! String) throw const FormatException('accountNumber must be a string');
    if (accountType is! String) throw const FormatException('accountType must be a string');

    return CreateBankAccountRequest(
      bankName: bankName,
      accountName: accountName,
      bsb: bsb,
      accountNumber: accountNumber,
      accountType: _parseType(accountType),
      currency: currency as String,
    );
  }

  static BankAccountType _parseType(String value) => switch (value) {
        'savings' => BankAccountType.savings,
        'termDeposit' || 'term_deposit' => BankAccountType.termDeposit,
        _ => BankAccountType.transaction,
      };
}
