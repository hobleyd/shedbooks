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

/// A saved mapping from an external GL code to a current GL account.
class BudgetGlMappingEntry {
  final String externalCode;
  final String externalName;
  final String generalLedgerId;

  const BudgetGlMappingEntry({
    required this.externalCode,
    required this.externalName,
    required this.generalLedgerId,
  });

  factory BudgetGlMappingEntry.fromJson(Map<String, dynamic> json) {
    return BudgetGlMappingEntry(
      externalCode: json['externalCode'] as String,
      externalName: json['externalName'] as String? ?? '',
      generalLedgerId: json['generalLedgerId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'externalCode': externalCode,
        'externalName': externalName,
        'generalLedgerId': generalLedgerId,
      };
}
