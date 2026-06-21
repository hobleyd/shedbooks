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

import 'package:excel/excel.dart' hide Border;

/// Parses Asset Register XLSX files into asset JSON maps.
///
/// All value-level helpers are public static methods so they can be unit-tested
/// independently of any Flutter widget.
class AssetXlsxParser {
  /// Sheet names that should be ignored during import.
  static const ignoredSheets = {'Revisions', 'Summary'};

  /// Cell values that represent an unknown / absent value.
  static const unknownValues = {'?', 'Unknown', 'Unkown', 'Unkwown', 'N/A'};

  /// Returns the year integer from [v], or null when unknown/unrecognised.
  ///
  /// Handles:
  /// - [IntCellValue] — used directly.
  /// - [DoubleCellValue] — truncated to int (Excel stores integers as floats).
  /// - `~YYYY` string — extracts the 4-digit year.
  /// - Bare 4-digit year string — accepted when in range 1900–2099.
  /// - Everything else (null, '?', 'Unknown', etc.) → null.
  static int? yearFromValue(CellValue? v) {
    if (v == null) return null;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value.toInt();
    final str = v.toString().trim();
    final approxMatch = RegExp(r'~(\d{4})').firstMatch(str);
    if (approxMatch != null) return int.tryParse(approxMatch.group(1)!);
    final year = int.tryParse(str);
    if (year != null && year > 1900 && year < 2100) return year;
    return null;
  }

  /// Returns the dollar amount as integer cents from [v], or null.
  ///
  /// Handles [IntCellValue], [DoubleCellValue] (rounded), and numeric strings.
  /// Returns null for null or non-numeric values.
  static int? centsFromValue(CellValue? v) {
    if (v == null) return null;
    if (v is IntCellValue) return v.value * 100;
    if (v is DoubleCellValue) return v.value.round() * 100;
    final str = v.toString().trim().replaceAll(RegExp(r'[,\$]'), '');
    final dollars = int.tryParse(str) ?? double.tryParse(str)?.round();
    if (dollars == null) return null;
    return dollars * 100;
  }

  /// Returns the text from [v], or null when empty or an [unknownValues] marker.
  static String? textFromValue(CellValue? v) {
    if (v == null) return null;
    final str = v.toString().trim();
    if (str.isEmpty || unknownValues.contains(str)) return null;
    return str;
  }

  /// Returns the raw text from [v], or null when empty. Does not filter unknowns.
  static String? rawTextFromValue(CellValue? v) {
    if (v == null) return null;
    final str = v.toString().trim();
    return str.isEmpty ? null : str;
  }

  /// Parses an Asset Register XLSX file and returns a list of asset JSON maps.
  ///
  /// Reads every sheet except those in [ignoredSheets]; uses the trimmed sheet
  /// name as `assetType`. Column layout:
  ///   0: Asset No, 1: Section (ignored), 2: Description, 3: Brand,
  ///   4: Identification, 5: Serial No, 6: Date of Manufacture (year),
  ///   7: Estimated Market Value (dollars → stored as cents)
  ///
  /// Rows where Description (col 2) is null/empty are skipped (pre-allocated
  /// empty slots). Rows where Asset No (col 0) is null/empty are also skipped.
  static List<Map<String, dynamic>> parseBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final assets = <Map<String, dynamic>>[];

    for (final sheetName in excel.tables.keys) {
      final trimmedName = sheetName.trim();
      if (ignoredSheets.contains(trimmedName)) continue;

      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;

      final rows = sheet.rows;
      // Row 0 is the header; data starts at row 1.
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        CellValue? cell(int col) => col < row.length ? row[col]?.value : null;

        final description = rawTextFromValue(cell(2));
        if (description == null) continue;

        final assetNo = rawTextFromValue(cell(0));
        if (assetNo == null) continue;

        assets.add({
          'assetNo': assetNo,
          'assetType': trimmedName,
          'description': description,
          'brand': textFromValue(cell(3)),
          'identification': textFromValue(cell(4)),
          'serialNo': textFromValue(cell(5)),
          'manufactureYear': yearFromValue(cell(6)),
          'estimatedMarketValueCents': centsFromValue(cell(7)),
        });
      }
    }

    return assets;
  }
}
