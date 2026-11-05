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

/// One member's line on the printable contact list.
class MemberContact {
  final String firstName;
  final String lastName;
  final String phone;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const MemberContact({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  /// Returns [contacts] sorted by last name then first name, ignoring case.
  static List<MemberContact> sorted(List<MemberContact> contacts) {
    return [...contacts]..sort((a, b) {
        final int cmp =
            a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
        return cmp != 0
            ? cmp
            : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      });
  }
}

/// Builds PDF content for the printable Member Contacts list.
class MemberContactsPdfReport {
  // Column widths (fits A4 with 50pt side margins):
  // First:85  Last:95  Phone:85  Emergency name:flex  Emergency phone:85
  static const double _firstW = 85;
  static const double _lastW = 95;
  static const double _phoneW = 85;
  static const double _emergencyPhoneW = 85;

  /// Returns the list of [pw.Widget]s to embed in a [pw.MultiPage].
  static List<pw.Widget> build({
    required List<MemberContact> contacts,
    required String asOf,
  }) {
    final List<MemberContact> rows = MemberContact.sorted(contacts);
    return [
      pw.Text('Member Contacts',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text('As at $asOf',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.0),
      _header(),
      pw.Divider(thickness: 0.3),
      ...rows.map(_row),
      pw.Divider(thickness: 1.0),
      pw.SizedBox(height: 8),
      pw.Text(
        '${rows.length} member${rows.length == 1 ? '' : 's'}',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
      ),
    ];
  }

  static pw.Widget _headerCell(String text) => pw.Text(text,
      style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700));

  static pw.Widget _header() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: _firstW, child: _headerCell('First Name')),
        pw.SizedBox(width: _lastW, child: _headerCell('Last Name')),
        pw.SizedBox(width: _phoneW, child: _headerCell('Contact Number')),
        pw.Expanded(child: _headerCell('Emergency Contact')),
        pw.SizedBox(
            width: _emergencyPhoneW, child: _headerCell('Emergency Number')),
      ]),
    );
  }

  static pw.Widget _cell(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 9));

  static pw.Widget _row(MemberContact c) {
    return pw.Column(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.SizedBox(width: _firstW, child: _cell(c.firstName)),
          pw.SizedBox(width: _lastW, child: _cell(c.lastName)),
          pw.SizedBox(width: _phoneW, child: _cell(c.phone)),
          pw.Expanded(child: _cell(c.emergencyContactName)),
          pw.SizedBox(
              width: _emergencyPhoneW, child: _cell(c.emergencyContactPhone)),
        ]),
      ),
      pw.Divider(thickness: 0.1, color: PdfColors.grey300),
    ]);
  }
}
