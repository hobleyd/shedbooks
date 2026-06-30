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

/// Request DTO for creating or updating entity details.
class SaveEntityDetailsRequest {
  final String name;
  final String abn;
  final String incorporationIdentifier;
  final String? apcaId;
  final String moneyInReceiptFormat;
  final String moneyOutReceiptFormat;
  final String invoiceNumberFormat;

  const SaveEntityDetailsRequest({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    this.apcaId,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
    required this.invoiceNumberFormat,
  });

  factory SaveEntityDetailsRequest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final abn = json['abn'];
    final inc = json['incorporationIdentifier'];
    final apcaId = json['apcaId'];
    final moneyIn = json['moneyInReceiptFormat'] ?? '';
    final moneyOut = json['moneyOutReceiptFormat'] ?? '';
    final invoiceFmt = json['invoiceNumberFormat'] ?? 'WMS-YY-###';

    if (name is! String) throw const FormatException('name must be a string');
    if (abn is! String) throw const FormatException('abn must be a string');
    if (inc is! String) {
      throw const FormatException('incorporationIdentifier must be a string');
    }
    if (apcaId != null && apcaId is! String) {
      throw const FormatException('apcaId must be a string');
    }
    if (moneyIn is! String) {
      throw const FormatException('moneyInReceiptFormat must be a string');
    }
    if (moneyOut is! String) {
      throw const FormatException('moneyOutReceiptFormat must be a string');
    }
    if (invoiceFmt is! String) {
      throw const FormatException('invoiceNumberFormat must be a string');
    }

    return SaveEntityDetailsRequest(
      name: name,
      abn: abn,
      incorporationIdentifier: inc,
      apcaId: apcaId,
      moneyInReceiptFormat: moneyIn,
      moneyOutReceiptFormat: moneyOut,
      invoiceNumberFormat: invoiceFmt,
    );
  }
}
