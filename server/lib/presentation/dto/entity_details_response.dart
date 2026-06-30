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

import '../../domain/entities/entity_details.dart';

/// Response DTO for entity details.
class EntityDetailsResponse {
  final String name;
  final String abn;
  final String incorporationIdentifier;
  final String? apcaId;
  final String moneyInReceiptFormat;
  final String moneyOutReceiptFormat;
  final String invoiceNumberFormat;

  const EntityDetailsResponse({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    this.apcaId,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
    required this.invoiceNumberFormat,
  });

  factory EntityDetailsResponse.fromEntity(EntityDetails e) =>
      EntityDetailsResponse(
        name: e.name,
        abn: e.abn,
        incorporationIdentifier: e.incorporationIdentifier,
        apcaId: e.apcaId,
        moneyInReceiptFormat: e.moneyInReceiptFormat,
        moneyOutReceiptFormat: e.moneyOutReceiptFormat,
        invoiceNumberFormat: e.invoiceNumberFormat,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'abn': abn,
        'incorporationIdentifier': incorporationIdentifier,
        'apcaId': apcaId,
        'moneyInReceiptFormat': moneyInReceiptFormat,
        'moneyOutReceiptFormat': moneyOutReceiptFormat,
        'invoiceNumberFormat': invoiceNumberFormat,
      };

  String toJsonString() => jsonEncode(toJson());
}
