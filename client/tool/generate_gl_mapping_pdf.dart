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
//
// One-off tool: builds the draft GL code-alignment PDF (shedbooks chart of
// accounts vs. the legacy Cashflow Manager codes seen in the 2025
// transaction listing) for circulation and comment. Not wired into the app;
// run directly with `dart run tool/generate_gl_mapping_pdf.dart`.

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum RowFlag { ok, conflict, gap, header }

class GlRow {
  final String code;
  final String description;
  final String ownMatch;
  final String proposed;
  final RowFlag flag;
  final String note;

  const GlRow(this.code, this.description, this.ownMatch, this.proposed, this.flag,
      [this.note = '']);
}

class GlSection {
  final String title;
  final String? anchorNote;
  final List<GlRow> rows;

  const GlSection(this.title, this.rows, {this.anchorNote});
}

const sections = <GlSection>[
  GlSection('Expense - standalone accounts', [
    GlRow('2-1000', 'Accounting Fees', '-', '6-00?? (invented)', RowFlag.gap,
        'No CFM code seen in 2025 data'),
    GlRow('2-1010', 'Audit Fees', '6-0050 Audit Fees', '6-0050', RowFlag.ok),
    GlRow('2-1030', 'Assets Purchased <\$5,000', '6-0040', '6-0040', RowFlag.ok),
    GlRow('2-1040', 'Bank Fees', '6-0070 Bank Charges', '6-0070', RowFlag.ok),
    GlRow('2-1050', 'Building Maintenance & Repair', '6-0170 (shared with Cleaning)',
        '6-0170', RowFlag.conflict, 'Same CFM code also used for general cleaning'),
    GlRow('2-1060', 'Postage, Freight, Courier', '-', '6-00?? (invented)', RowFlag.gap,
        'No CFM code seen'),
    GlRow('2-1070', 'Printing & Stationary', '6-0520', '6-0520', RowFlag.ok),
  ]),
  GlSection('Expense - Advertising & Promotion family', [
    GlRow('2-1020', 'Advertising & Promotion (parent)', '-', '6-0?xx (invented)',
        RowFlag.gap),
    GlRow('2-1025', 'Community Expo', '-', '6-0?xx-25', RowFlag.gap),
  ]),
  GlSection(
    "Expense - Member's Expenses family",
    [
      GlRow('2-2000', "Member's Expenses (parent)", '-', '6-0110', RowFlag.header),
      GlRow('2-2000-10', 'Cleaning', 'contested (6-0170, shared w/ Building Maint.)',
          '6-0110-10', RowFlag.conflict,
          'Needs decision: own code or share 6-0170?'),
      GlRow('2-2000-20', 'Morning Tea', '6-0110 Morning Teas', '6-0110-20',
          RowFlag.conflict, 'Redundant - matches the family anchor itself'),
      GlRow('2-2000-30', 'Fellowship', '6-0120 Fellowship (BBQ etc)', '6-0110-30',
          RowFlag.conflict, 'Anchor discards real 6-0120 match'),
      GlRow('2-2000-40', 'Travel Expenses', '-', '6-0110-40', RowFlag.gap),
    ],
    anchorNote: 'Anchor: 6-0110 (Morning Tea - first child with a clean match)',
  ),
  GlSection(
    'Expense - Fundraising family',
    [
      GlRow('2-3000', 'Fundraising (parent)', '-', '6-0340', RowFlag.header),
      GlRow('2-3000-10', 'Easter Fair expenses', '6-0340 (direct)', '6-0340-10',
          RowFlag.ok),
      GlRow('2-3000-20', 'Recycling', '6-0360 Fundraising Exp - Recycling', '6-0340-20',
          RowFlag.conflict, 'Anchor discards real 6-0360'),
      GlRow('2-3000-30', 'Garden expenses', '6-0350 Fundraising Exp - Garden Sale',
          '6-0340-30', RowFlag.conflict, 'Anchor discards real 6-0350'),
      GlRow('2-3000-40', 'Other fundraising expenses', '6-0370 Fundraising Exp - Other',
          '6-0340-40', RowFlag.conflict, 'Anchor discards real 6-0370'),
      GlRow('2-3000-50', 'Markets BBQ', '-', '6-0340-50', RowFlag.gap),
      GlRow('2-3000-60', 'Trailer Repair', '-', '6-0340-60', RowFlag.gap),
      GlRow('2-3000-65', 'Mobility Scooter', '-', '6-0340-65', RowFlag.gap),
      GlRow('2-3000-70', 'Adirondack Chairs', '-', '6-0340-70', RowFlag.gap),
    ],
    anchorNote: 'Anchor: 6-0340 (Easter Fair expenses - first child with a clean match)',
  ),
  GlSection(
    'Expense - Rent & Insurance family (original example)',
    [
      GlRow('2-4000', 'Rent & Insurance (parent)', '-', '6-0400', RowFlag.header),
      GlRow('2-4000-10', 'AMSA', '6-0400 Insurances', '6-0400-10', RowFlag.ok),
      GlRow('2-4000-20', 'Other insurance', '6-0400 (shared with AMSA)', '6-0400-20',
          RowFlag.conflict, "CFM doesn't split insurance types"),
      GlRow('2-4000-30', 'Rent', '6-0180 Rental charges', '6-0400-30', RowFlag.conflict,
          'Anchor discards real 6-0180 (your original example)'),
      GlRow('2-4000-40', 'Rates', '6-0550 Rates and Taxes', '6-0400-40',
          RowFlag.conflict, 'Anchor discards real 6-0550'),
      GlRow('2-4000-50', 'Telephony & Internet', '6-0620 Telephone', '6-0400-50',
          RowFlag.conflict, 'Anchor discards real 6-0620'),
    ],
    anchorNote: 'Anchor: 6-0400 (AMSA - first child with a clean match)',
  ),
  GlSection(
    'Expense - Motor Vehicle family',
    [
      GlRow('2-5000', 'Motor Vehicle (parent)', '-', '6-0501', RowFlag.header),
      GlRow('2-5000-10', 'Fuel, Oil, Maintenance', '6-0501 (direct)', '6-0501-10',
          RowFlag.ok),
      GlRow('2-5000-20', 'Registration', '6-0502 Registration', '6-0501-20',
          RowFlag.conflict, 'Anchor discards real 6-0502'),
      GlRow('2-5000-30', 'Vehicle Insurance', '-', '6-0501-30', RowFlag.gap,
          'Likely folded into 6-0400 in CFM'),
    ],
    anchorNote: 'Anchor: 6-0501 (Fuel, Oil, Maintenance - first child with a clean match)',
  ),
  GlSection(
    'Expense - Sundry family',
    [
      GlRow('2-6000', 'Sundry (parent)', '-', '6-0300', RowFlag.header),
      GlRow('2-6000-10', 'Donations Paid', '6-0300 (direct)', '6-0300-10', RowFlag.ok),
    ],
    anchorNote: 'Anchor: 6-0300 (Donations Paid - only child)',
  ),
  GlSection(
    'Expense - Workshop family (structural fix: linking under one parent)',
    [
      GlRow('2-7000', 'Workshop (parent)', '-', '6-0140', RowFlag.header),
      GlRow('2-7010', 'Workshop Equipment repair', '6-0140 (direct)', '6-0140-10',
          RowFlag.ok),
      GlRow('2-7015', 'CNC Machine', '6-0140 (no distinct code; shares parent)',
          '6-0140-15', RowFlag.conflict),
      GlRow('2-7020', 'Workshop Consumables', '6-0130 Workshop Consumables',
          '6-0140-20', RowFlag.conflict, 'Anchor discards real 6-0130'),
      GlRow('2-7030', 'Garden Consumables', '-', '6-0140-30', RowFlag.gap),
    ],
    anchorNote: 'Anchor: 6-0140 (Workshop Equipment repair - first child with a clean match). '
        '2-7010/15/20/30 are not currently linked via parent_id to 2-7000 - to be fixed as part of this pass.',
  ),
  GlSection('Income - standalone accounts', [
    GlRow('4-1000', 'Grants Received', '4-1010 Grants Recieved', '4-1010', RowFlag.ok),
    GlRow('4-3000', 'GST Refunds (ATO)', '4-4070 GST Refunds (ATO)', '4-4070',
        RowFlag.ok),
    GlRow('4-4000', 'Solar Power Feed-In', '4-5040 Solar Feed-in Tariffs', '4-5040',
        RowFlag.ok),
  ]),
  GlSection(
    'Income - Fundraising family',
    [
      GlRow('4-2000', 'Fundraising (parent)', '-', '4-2010', RowFlag.header),
      GlRow('4-2000-10', 'Donations Received', '4-2010 (direct)', '4-2010-10',
          RowFlag.ok),
      GlRow('4-2000-20', 'Easter Fair', '4-2020', '4-2010-20', RowFlag.conflict,
          'Anchor discards real 4-2020'),
      GlRow('4-2000-25', 'Markets BBQ', '-', '4-2010-25', RowFlag.gap),
      GlRow('4-2000-30', 'Garden Sales', '4-2030', '4-2010-30', RowFlag.conflict,
          'Anchor discards real 4-2030'),
      GlRow('4-2000-40', 'Woodworking Sales', 'generic 4-4010 pool only', '4-2010-40',
          RowFlag.gap, 'Low confidence - CFM code is not workshop-specific'),
      GlRow('4-2000-50', 'Metalworking Sales', 'generic 4-4010 pool only', '4-2010-50',
          RowFlag.gap, 'Low confidence - CFM code is not workshop-specific'),
      GlRow('4-2000-60', 'Recycling', '4-2050', '4-2010-60', RowFlag.conflict,
          'Anchor discards real 4-2050'),
      GlRow('4-2000-70', 'Mobility Aids', 'possible: 4-2060 "Fundraising - Other 1"',
          '4-2010-70', RowFlag.conflict, 'Low-confidence candidate, generic bucket'),
      GlRow('4-2000-75', 'Onward sale of donated goods', '4-5035', '4-2010-75',
          RowFlag.conflict, 'Anchor discards real 4-5035'),
      GlRow('4-2000-80', 'Member Contributions', '4-3010', '4-2010-80',
          RowFlag.conflict, 'Anchor discards real 4-3010'),
      GlRow('4-2000-85', 'Shirt Sales', '-', '4-2010-85', RowFlag.gap),
      GlRow('4-2000-90', 'Membership', '4-4080', '4-2010-90', RowFlag.conflict,
          'Anchor discards real 4-4080'),
    ],
    anchorNote: 'Anchor: 4-2010 (Donations Received - first child with a clean match)',
  ),
  GlSection(
    'Income - Projects family',
    [
      GlRow('4-5000', 'Projects (parent)', '-', 'invented', RowFlag.gap,
          'No anchor available'),
      GlRow('4-5000-10', 'Adirondack Chairs', 'low confidence: 4-2040 Garage Sale',
          'invented', RowFlag.gap),
      GlRow('4-5000-20', 'Trailer', 'low confidence: 4-2010 Donations', 'invented',
          RowFlag.gap),
      GlRow('4-5000-30', 'Read To Me', '-', 'invented', RowFlag.gap),
    ],
    anchorNote: 'No child in this family has a confident CFM match - whole family stays invented.',
  ),
  GlSection(
    'Income - Sundry family',
    [
      GlRow('4-9000', 'Sundry (parent)', '-', '4-5020', RowFlag.header),
      GlRow('4-9000-10', 'Bank Interest', '4-5020 (granularity note below)',
          '4-5020-10', RowFlag.conflict,
          'CFM splits interest by bank account; shedbooks combines'),
      GlRow('4-9000-20', 'Gain on sale of non-current assets', '4-5060', '4-5020-20',
          RowFlag.conflict, 'Anchor discards real 4-5060'),
      GlRow('4-9000-30', 'Community Expo', '-', '4-5020-30', RowFlag.gap),
    ],
    anchorNote: 'Anchor: 4-5020 (Bank Interest - first child with a clean match)',
  ),
];

const gapAccounts = <List<String>>[
  ['4-2040', 'Fundraising - Garage Sale'],
  ['4-4010', 'Sale of Goods (other than Fundraising) - generic'],
  ['4-2060', 'Fundraising - Other 1'],
  ['4-4030 / 6-0060', 'Internal cash transfers IN / OUT - likely unnecessary; shedbooks handles inter-account transfers via the bank-transfer feature, not a GL code'],
  ['6-0150', 'Project Sales Expenses'],
  ['6-0160', 'Members Expenses - Purchases for resale'],
  ['6-0220', 'Computer Expenses'],
  ['6-0395', 'Health and Safety Expenses'],
  ['4-4090', 'Miscellaneous income'],
];

Future<void> main() async {
  final doc = pw.Document(
      title: 'Woodgate Mens Shed - GL Code Alignment (Draft for Comment)');
  final generated = _formatDate(DateTime.now());

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
    header: (ctx) {
      if (ctx.pageNumber == 1) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Woodgate Mens Shed - GL Code Alignment (Draft for Comment) (continued)',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 4),
        ],
      );
    },
    footer: (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated $generated - DRAFT, no changes applied yet',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
        ],
      ),
    ),
    build: (ctx) => [
      pw.Text('Woodgate Mens Shed Inc',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.Text('Chart of Accounts Alignment: Cashflow Manager -> Shedbooks',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.Text('DRAFT FOR COMMENT - no changes have been made yet',
          style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.orange700,
              fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Text(
        'This compares the shedbooks chart of accounts against the GL codes used in the '
        '2025 Cashflow Manager transaction listing. Proposed codes use each shedbooks '
        "parent group's best-matching child as a family \"anchor\", with siblings that "
        'have no code of their own following the anchor. Rows flagged with a warning '
        'below show where that anchor discards a more specific, directly-matched code '
        'for that account - please mark your preferred resolution against those rows.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 8),
      _legend(),
      pw.SizedBox(height: 14),
      for (final section in sections) ...[
        _sectionTable(section),
        pw.SizedBox(height: 12),
      ],
      pw.SizedBox(height: 6),
      pw.Text('CFM codes with no shedbooks account',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.Text(
        'Seen in the 2025 transactions but not represented anywhere in the current '
        'shedbooks chart. These need a decision before the transaction import, '
        'independent of the renumbering above.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 6),
      _gapTable(),
      pw.SizedBox(height: 14),
      pw.Text('Flagged for the transaction-import phase only (no chart action needed now)',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.Bullet(
          text:
              'CFM code 6-0170 was used for both Building Maintenance and general Cleaning transactions.'),
      pw.Bullet(text: r'A few `6=0060`-style typos appear in the source export.'),
      pw.Bullet(
          text:
              'One term-deposit interest transaction was coded "199" in Cashflow Manager - not a valid GL code, likely a data-entry error.'),
    ],
  ));

  final bytes = await doc.save();
  final outPath = Platform.environment['GL_PDF_OUT'] ??
      '${Directory.current.path}/gl_code_alignment_draft.pdf';
  await File(outPath).writeAsBytes(bytes);
  stdout.writeln('Wrote $outPath (${bytes.length} bytes)');
}

pw.Widget _legend() {
  pw.Widget item(PdfColor color, String symbol, String label) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(symbol, style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(width: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(width: 14),
        ],
      );
  return pw.Row(children: [
    item(PdfColors.green700, 'OK', 'clean match, no conflict'),
    item(PdfColors.orange700, '!', 'anchor overrides a real match / needs a decision'),
    item(PdfColors.grey600, '?', 'gap - no CFM code seen, code invented'),
  ]);
}

pw.Widget _sectionTable(GlSection section) {
  final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white);
  final cellStyle = const pw.TextStyle(fontSize: 8);
  const colWidths = {
    0: pw.FlexColumnWidth(1.3),
    1: pw.FlexColumnWidth(2.2),
    2: pw.FlexColumnWidth(2.6),
    3: pw.FlexColumnWidth(1.4),
    4: pw.FlexColumnWidth(0.5),
    5: pw.FlexColumnWidth(3.0),
  };

  pw.Widget cell(String text, {pw.TextStyle? style, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        child: pw.Text(text, style: style ?? cellStyle, textAlign: align),
      );

  pw.Widget flagCell(RowFlag flag) {
    switch (flag) {
      case RowFlag.ok:
        return cell('OK',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.green700, fontWeight: pw.FontWeight.bold),
            align: pw.TextAlign.center);
      case RowFlag.conflict:
        return cell('!',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.orange700, fontWeight: pw.FontWeight.bold),
            align: pw.TextAlign.center);
      case RowFlag.gap:
        return cell('?',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
            align: pw.TextAlign.center);
      case RowFlag.header:
        return cell('');
    }
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        color: PdfColors.grey800,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Text(section.title,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white)),
      ),
      if (section.anchorNote != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
          child: pw.Text(section.anchorNote!,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
        ),
      pw.Table(
        columnWidths: colWidths,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey600),
            children: [
              cell('Code', style: headerStyle),
              cell('Description', style: headerStyle),
              cell('CFM match', style: headerStyle),
              cell('Proposed', style: headerStyle),
              cell('', style: headerStyle),
              cell('Note', style: headerStyle),
            ],
          ),
          ...section.rows.asMap().entries.map((e) {
            final row = e.value;
            final isHeader = row.flag == RowFlag.header;
            final bg = isHeader
                ? PdfColors.grey300
                : (e.key.isEven ? PdfColors.grey100 : PdfColors.white);
            final textStyle = isHeader
                ? pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)
                : cellStyle;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                cell(row.code, style: textStyle),
                cell(row.description, style: textStyle),
                cell(row.ownMatch, style: textStyle),
                cell(row.proposed, style: textStyle),
                flagCell(row.flag),
                cell(row.note, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ],
            );
          }),
        ],
      ),
    ],
  );
}

pw.Widget _gapTable() {
  final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white);
  const colWidths = {0: pw.FlexColumnWidth(1.5), 1: pw.FlexColumnWidth(5)};

  pw.Widget cell(String text, {pw.TextStyle? style}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
        child: pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 8)),
      );

  return pw.Table(
    columnWidths: colWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey600),
        children: [cell('CFM code', style: headerStyle), cell('Description', style: headerStyle)],
      ),
      ...gapAccounts.asMap().entries.map((e) => pw.TableRow(
            decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.grey100 : PdfColors.white),
            children: [cell(e.value[0]), cell(e.value[1])],
          )),
    ],
  );
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
