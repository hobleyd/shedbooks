import 'dart:convert';

import '../../domain/entities/bank_import.dart';

/// JSON response for a single [BankImport].
class BankImportResponse {
  final String processDate;
  final String description;
  final int amountCents;
  final bool isDebit;

  const BankImportResponse({
    required this.processDate,
    required this.description,
    required this.amountCents,
    required this.isDebit,
  });

  factory BankImportResponse.fromEntity(BankImport e) => BankImportResponse(
        processDate: e.processDate,
        description: e.description,
        amountCents: e.amountCents,
        isDebit: e.isDebit,
      );

  Map<String, dynamic> toJson() => {
        'processDate': processDate,
        'description': description,
        'amountCents': amountCents,
        'isDebit': isDebit,
      };

  static String toJsonList(List<BankImportResponse> items) =>
      jsonEncode(items.map((i) => i.toJson()).toList());
}
