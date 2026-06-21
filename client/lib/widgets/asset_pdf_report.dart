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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/asset_entry.dart';

/// Summary of assets in one section, derived from [AssetEntry] lists.
class AssetSectionSummary {
  final String section;
  final int count;

  /// Sum of estimated market values in cents (null values count as zero).
  final int totalCents;

  /// True when at least one asset in this section has a value recorded.
  final bool hasValue;

  const AssetSectionSummary({
    required this.section,
    required this.count,
    required this.totalCents,
    required this.hasValue,
  });

  /// Computes section summaries from [assets], sorted alphabetically by section.
  static List<AssetSectionSummary> fromAssets(List<AssetEntry> assets) {
    final Map<String, List<AssetEntry>> bySection = {};
    for (final a in assets) {
      (bySection[a.assetType] ??= []).add(a);
    }
    return bySection.entries.map((e) {
      int total = 0;
      bool hasValue = false;
      for (final a in e.value) {
        if (a.estimatedMarketValueCents != null) {
          total += a.estimatedMarketValueCents!;
          hasValue = true;
        }
      }
      return AssetSectionSummary(
        section: e.key,
        count: e.value.length,
        totalCents: total,
        hasValue: hasValue,
      );
    }).toList()
      ..sort((a, b) => a.section.compareTo(b.section));
  }
}

/// Builds PDF content for the Assets report.
class AssetPdfReport {
  /// Returns the list of [pw.Widget]s to embed in a [pw.MultiPage].
  static List<pw.Widget> build({
    required List<AssetSectionSummary> sections,
    required List<AssetEntry> allAssets,
    required bool includeFullRegister,
    required String Function(int) formatCents,
    required String asOf,
  }) {
    final grandCount = sections.fold(0, (sum, s) => sum + s.count);
    final grandTotal = sections.fold(0, (sum, s) => sum + s.totalCents);

    return [
      pw.Text('Asset Register Summary',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text('As at $asOf',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.0),
      _summaryHeader(),
      pw.Divider(thickness: 0.3),
      ...sections.map((s) => _summaryRow(s, formatCents)),
      pw.Divider(thickness: 1.0),
      _totalRow(grandCount, grandTotal, formatCents),
      pw.SizedBox(height: 8),
      pw.Text(
        '$grandCount asset${grandCount == 1 ? '' : 's'} in '
        '${sections.length} section${sections.length == 1 ? '' : 's'}',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
      ),
      if (includeFullRegister) ...[
        pw.SizedBox(height: 20),
        pw.Text('Full Asset Register',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Divider(thickness: 1.0),
        pw.SizedBox(height: 4),
        ..._buildFullRegister(sections, allAssets, formatCents),
      ],
    ];
  }

  static pw.Widget _summaryHeader() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text('Section',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
        ),
        pw.SizedBox(
          width: 55,
          child: pw.Text('Assets',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(
          width: 110,
          child: pw.Text('Est. Value',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700),
              textAlign: pw.TextAlign.right),
        ),
      ]),
    );
  }

  static pw.Widget _summaryRow(
      AssetSectionSummary s, String Function(int) formatCents) {
    return pw.Column(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(s.section, style: const pw.TextStyle(fontSize: 9))),
          pw.SizedBox(
            width: 55,
            child: pw.Text('${s.count}',
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right),
          ),
          pw.SizedBox(
            width: 110,
            child: pw.Text(
                s.hasValue ? formatCents(s.totalCents) : '—',
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.right),
          ),
        ]),
      ),
      pw.Divider(thickness: 0.1, color: PdfColors.grey300),
    ]);
  }

  static pw.Widget _totalRow(
      int count, int totalCents, String Function(int) formatCents) {
    return pw.Container(
      color: PdfColors.grey100,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Text('Total',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(
          width: 55,
          child: pw.Text('$count',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(
          width: 110,
          child: pw.Text(formatCents(totalCents),
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right),
        ),
      ]),
    );
  }

  // ── Full asset register ────────────────────────────────────────────────────

  static List<pw.Widget> _buildFullRegister(
    List<AssetSectionSummary> sections,
    List<AssetEntry> allAssets,
    String Function(int) formatCents,
  ) {
    final Map<String, List<AssetEntry>> bySection = {};
    for (final a in allAssets) {
      (bySection[a.assetType] ??= []).add(a);
    }
    for (final list in bySection.values) {
      list.sort((a, b) => a.assetNo.compareTo(b.assetNo));
    }

    final result = <pw.Widget>[];
    for (final s in sections) {
      final sectionAssets = bySection[s.section] ?? [];
      result.addAll([
        pw.SizedBox(height: 8),
        _registerSectionHeader(s.section),
        pw.Divider(thickness: 0.3),
        ...sectionAssets.map((a) => _registerAssetRow(a, formatCents)),
        pw.Divider(thickness: 0.4, color: PdfColors.grey400),
      ]);
    }
    return result;
  }

  // Column widths for the full register (fits A4 with 50pt side margins):
  // AssetNo:55  Description:flex  Brand:70  Year:38  Est.Value:75
  static pw.Widget _registerSectionHeader(String section) {
    return pw.Container(
      color: PdfColors.grey200,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 55,
          child: pw.Text('Asset No',
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(section,
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(
          width: 70,
          child: pw.Text('Brand',
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
        ),
        pw.SizedBox(
          width: 38,
          child: pw.Text('Year',
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(
          width: 75,
          child: pw.Text('Est. Value',
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700),
              textAlign: pw.TextAlign.right),
        ),
      ]),
    );
  }

  static pw.Widget _registerAssetRow(
      AssetEntry a, String Function(int) formatCents) {
    return pw.Column(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(a.assetNo,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(a.description ?? '',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text(a.brand ?? '',
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.SizedBox(
            width: 38,
            child: pw.Text(a.manufactureYear?.toString() ?? '',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.right),
          ),
          pw.SizedBox(
            width: 75,
            child: pw.Text(
                a.estimatedMarketValueCents != null
                    ? formatCents(a.estimatedMarketValueCents!)
                    : '—',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.right),
          ),
        ]),
      ),
      pw.Divider(thickness: 0.1, color: PdfColors.grey200),
    ]);
  }
}
