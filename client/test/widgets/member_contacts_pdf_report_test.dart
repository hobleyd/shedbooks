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

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shedbooks_client/widgets/member_contacts_pdf_report.dart';

MemberContact _contact(String first, String last) => MemberContact(
      firstName: first,
      lastName: last,
      phone: '0400 000 000',
      emergencyContactName: 'Someone',
      emergencyContactPhone: '0411 111 111',
    );

void main() {
  group('MemberContact.sorted', () {
    test('sorts by last name then first name, ignoring case', () {
      // Arrange
      final List<MemberContact> contacts = [
        _contact('Zoe', 'smith'),
        _contact('Adam', 'Smith'),
        _contact('Bob', 'Jones'),
      ];

      // Act
      final List<MemberContact> result = MemberContact.sorted(contacts);

      // Assert
      expect(result.map((c) => '${c.firstName} ${c.lastName}').toList(),
          ['Bob Jones', 'Adam Smith', 'Zoe smith']);
    });

    test('does not modify the input list', () {
      // Arrange
      final List<MemberContact> contacts = [
        _contact('Zoe', 'Smith'),
        _contact('Bob', 'Jones'),
      ];

      // Act
      MemberContact.sorted(contacts);

      // Assert
      expect(contacts.first.firstName, 'Zoe');
    });
  });

  group('MemberContactsPdfReport.build', () {
    test('produces a PDF document that saves without error', () async {
      // Arrange
      final pw.Document doc = pw.Document();
      final List<MemberContact> contacts =
          List.generate(80, (i) => _contact('First$i', 'Last$i'));

      // Act
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) =>
            MemberContactsPdfReport.build(contacts: contacts, asOf: '05/11/2026'),
      ));
      final List<int> bytes = await doc.save();

      // Assert
      expect(bytes, isNotEmpty);
    });
  });
}
