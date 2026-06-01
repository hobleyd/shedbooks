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

  const BankAccountResponse({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.bsb,
    required this.accountNumber,
    required this.accountType,
    required this.currency,
    required this.isSystem,
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
      };

  String toJsonString() => jsonEncode(toJson());
}
