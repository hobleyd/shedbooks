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

import 'dart:convert';

import '../../domain/entities/bank_account.dart';

/// Response DTO for a bank account.
class BankAccountResponse {
  final String id;
  final String bankName;
  final String accountName;
  final String bsb;
  final String accountNumber;
  final String accountType;
  final String currency;
  final bool isSystem;
  final int sortOrder;

  const BankAccountResponse({
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

  factory BankAccountResponse.fromEntity(BankAccount e) =>
      BankAccountResponse(
        id: e.id,
        bankName: e.bankName,
        accountName: e.accountName,
        bsb: e.bsb,
        accountNumber: e.accountNumber,
        accountType: switch (e.accountType) {
          BankAccountType.transaction => 'transaction',
          BankAccountType.savings => 'savings',
          BankAccountType.termDeposit => 'termDeposit',
          BankAccountType.cash => 'cash',
        },
        currency: e.currency,
        isSystem: e.isSystem,
        sortOrder: e.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'accountName': accountName,
        'bsb': bsb,
        'accountNumber': accountNumber,
        'accountType': accountType,
        'currency': currency,
        'isSystem': isSystem,
        'sortOrder': sortOrder,
      };

  String toJsonString() => jsonEncode(toJson());
}
