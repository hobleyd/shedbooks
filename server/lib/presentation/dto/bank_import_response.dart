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
