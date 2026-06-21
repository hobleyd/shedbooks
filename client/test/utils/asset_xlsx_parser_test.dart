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
import 'package:flutter_test/flutter_test.dart';

import 'package:shedbooks_client/utils/asset_xlsx_parser.dart';

void main() {
  // ── yearFromValue ──────────────────────────────────────────────────────────

  group('AssetXlsxParser.yearFromValue', () {
    test('null → null', () {
      expect(AssetXlsxParser.yearFromValue(null), isNull);
    });

    test('IntCellValue returns the integer directly', () {
      expect(AssetXlsxParser.yearFromValue(IntCellValue(2023)), equals(2023));
    });

    test('DoubleCellValue truncates to int (Excel stores ints as floats)', () {
      expect(AssetXlsxParser.yearFromValue(DoubleCellValue(2015.0)), equals(2015));
    });

    test('~YYYY string extracts the year', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('~2020')), equals(2020));
    });

    test('~YYYY string with extra whitespace extracts the year', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue(' ~2018 ')), equals(2018));
    });

    test('bare 4-digit year string in valid range', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('1999')), equals(1999));
    });

    test('year string at upper boundary (2099) is accepted', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('2099')), equals(2099));
    });

    test('year string at lower boundary (1901) is accepted', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('1901')), equals(1901));
    });

    test('"?" → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('?')), isNull);
    });

    test('"Unknown" → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('Unknown')), isNull);
    });

    test('"Unkown" (typo) → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('Unkown')), isNull);
    });

    test('"Unkwown" (typo) → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('Unkwown')), isNull);
    });

    test('"N/A" → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('N/A')), isNull);
    });

    test('arbitrary non-year text → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('approx 2010')), isNull);
    });

    test('year 1900 (boundary, exclusive) → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('1900')), isNull);
    });

    test('year 2100 (boundary, exclusive) → null', () {
      expect(AssetXlsxParser.yearFromValue(TextCellValue('2100')), isNull);
    });
  });

  // ── centsFromValue ─────────────────────────────────────────────────────────

  group('AssetXlsxParser.centsFromValue', () {
    test('null → null', () {
      expect(AssetXlsxParser.centsFromValue(null), isNull);
    });

    test('IntCellValue 1500 → 150000 cents', () {
      expect(AssetXlsxParser.centsFromValue(IntCellValue(1500)), equals(150000));
    });

    test('IntCellValue 0 → 0 cents', () {
      expect(AssetXlsxParser.centsFromValue(IntCellValue(0)), equals(0));
    });

    test('DoubleCellValue 2500.0 → 250000 cents', () {
      expect(AssetXlsxParser.centsFromValue(DoubleCellValue(2500.0)), equals(250000));
    });

    test('DoubleCellValue with fractional cents rounds to nearest dollar', () {
      // 1500.6 rounds to 1501 dollars → 150100 cents
      expect(AssetXlsxParser.centsFromValue(DoubleCellValue(1500.6)), equals(150100));
    });

    test('numeric string "300" → 30000 cents', () {
      expect(AssetXlsxParser.centsFromValue(TextCellValue('300')), equals(30000));
    });

    test('numeric string with dollar sign "\$4500" → 450000 cents', () {
      expect(AssetXlsxParser.centsFromValue(TextCellValue('\$4500')), equals(450000));
    });

    test('numeric string with comma "1,000" → 100000 cents', () {
      expect(AssetXlsxParser.centsFromValue(TextCellValue('1,000')), equals(100000));
    });

    test('non-numeric text → null', () {
      expect(AssetXlsxParser.centsFromValue(TextCellValue('unknown')), isNull);
    });

    test('"?" → null', () {
      expect(AssetXlsxParser.centsFromValue(TextCellValue('?')), isNull);
    });
  });

  // ── textFromValue ──────────────────────────────────────────────────────────

  group('AssetXlsxParser.textFromValue', () {
    test('null → null', () {
      expect(AssetXlsxParser.textFromValue(null), isNull);
    });

    test('regular text is returned', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('Holden')), equals('Holden'));
    });

    test('text is trimmed', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('  Holden  ')), equals('Holden'));
    });

    test('empty string → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('')), isNull);
    });

    test('whitespace-only → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('   ')), isNull);
    });

    test('"?" → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('?')), isNull);
    });

    test('"Unknown" → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('Unknown')), isNull);
    });

    test('"Unkown" (typo) → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('Unkown')), isNull);
    });

    test('"Unkwown" (typo) → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('Unkwown')), isNull);
    });

    test('"N/A" → null', () {
      expect(AssetXlsxParser.textFromValue(TextCellValue('N/A')), isNull);
    });

    test('IntCellValue text representation is returned', () {
      // Brand field would typically be text; if someone entered a number, return it.
      expect(AssetXlsxParser.textFromValue(IntCellValue(42)), equals('42'));
    });
  });

  // ── rawTextFromValue ───────────────────────────────────────────────────────

  group('AssetXlsxParser.rawTextFromValue', () {
    test('null → null', () {
      expect(AssetXlsxParser.rawTextFromValue(null), isNull);
    });

    test('regular text is returned', () {
      expect(AssetXlsxParser.rawTextFromValue(TextCellValue('2026-W-0001')), equals('2026-W-0001'));
    });

    test('text is trimmed', () {
      expect(AssetXlsxParser.rawTextFromValue(TextCellValue('  2026-W-0001  ')), equals('2026-W-0001'));
    });

    test('empty string → null', () {
      expect(AssetXlsxParser.rawTextFromValue(TextCellValue('')), isNull);
    });

    test('whitespace-only → null', () {
      expect(AssetXlsxParser.rawTextFromValue(TextCellValue('   ')), isNull);
    });

    test('"?" is NOT filtered (raw access)', () {
      expect(AssetXlsxParser.rawTextFromValue(TextCellValue('?')), equals('?'));
    });

    test('"Unknown" is NOT filtered (raw access)', () {
      expect(AssetXlsxParser.rawTextFromValue(TextCellValue('Unknown')), equals('Unknown'));
    });

    test('IntCellValue number returned as string', () {
      expect(AssetXlsxParser.rawTextFromValue(IntCellValue(1001)), equals('1001'));
    });

    test('DoubleCellValue number returned as string', () {
      expect(AssetXlsxParser.rawTextFromValue(DoubleCellValue(1001.0)), equals('1001.0'));
    });
  });
}
