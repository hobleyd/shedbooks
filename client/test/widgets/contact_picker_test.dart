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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/models/contact_entry.dart';
import 'package:shedbooks_client/widgets/contact_picker.dart';

const _existingContact = ContactEntry(
  id: 'c1',
  name: 'Acme Corp',
  contactType: ContactType.company,
  gstRegistered: true,
  abn: '51824753556',
  address: '1 Main St\nSydney NSW 2000',
);

Widget _harness(ContactPickerController controller) => MaterialApp(
      home: Scaffold(
        body: ContactPicker(controller: controller),
      ),
    );

TextField _addressTextField(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Address'),
        matching: find.byType(TextField),
      ),
    );

TextField _nameTextField(WidgetTester tester) => tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Name'),
        matching: find.byType(TextField),
      ),
    );

void main() {
  testWidgets('new contact: Address field is a multi-line, editable field',
      (tester) async {
    // Arrange
    final controller = ContactPickerController()..setToNew();
    addTearDown(controller.dispose);

    // Act
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Assert
    expect(find.widgetWithText(TextFormField, 'Address'), findsOneWidget);
    final addressField = _addressTextField(tester);
    expect(addressField.maxLines, greaterThan(1));
    expect(addressField.enabled, isTrue);
  });

  testWidgets(
      'existing contact: Address is pre-filled and stays editable while Name is locked',
      (tester) async {
    // Arrange
    final controller = ContactPickerController()
      ..selectContact(_existingContact);
    addTearDown(controller.dispose);

    // Act
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Assert
    expect(controller.addressController.text, _existingContact.address);
    final addressField = _addressTextField(tester);
    expect(addressField.enabled, isTrue,
        reason: 'address must stay editable for an existing contact so it '
            'can be captured/updated from the invoice screen');
    final nameField = _nameTextField(tester);
    expect(nameField.enabled, isFalse,
        reason: 'other contact fields remain locked for an existing contact');
  });

  testWidgets('editing the address field updates the controller',
      (tester) async {
    // Arrange
    final controller = ContactPickerController()
      ..selectContact(_existingContact);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Act
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '2 Other St\nMelbourne VIC 3000',
    );

    // Assert
    expect(controller.addressController.text, '2 Other St\nMelbourne VIC 3000');
  });

  testWidgets('Type selector is shown for a new contact when onlyCompanies is false',
      (tester) async {
    // Arrange
    final controller = ContactPickerController()..setToNew();
    addTearDown(controller.dispose);

    // Act
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Assert — invoices can be raised against individuals, not just companies
    expect(find.widgetWithText(DropdownButtonFormField<ContactType>, 'Type'),
        findsOneWidget);
  });

  testWidgets('Type selector is hidden when onlyCompanies is true', (tester) async {
    // Arrange
    final controller = ContactPickerController(onlyCompanies: true)..setToNew();
    addTearDown(controller.dispose);

    // Act
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Assert
    expect(find.widgetWithText(DropdownButtonFormField<ContactType>, 'Type'),
        findsNothing);
  });

  testWidgets(
      'setContactType(person) clears ABN, disables GST, and notifies listeners '
      'so dependents (e.g. invoice line-item GST) recompute', (tester) async {
    // Arrange
    final controller = ContactPickerController()..setToNew();
    addTearDown(controller.dispose);
    controller.contactType = ContactType.company;
    controller.gstRegistered = true;
    controller.abnController.text = '51824753556';
    var notified = false;
    controller.addListener(() => notified = true);
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Act
    controller.setContactType(ContactType.person);
    await tester.pump();

    // Assert
    expect(notified, isTrue);
    expect(controller.gstRegistered, isFalse);
    expect(controller.abnController.text, isEmpty);
  });

  testWidgets('setGstRegistered notifies listeners so line-item GST recomputes',
      (tester) async {
    // Arrange
    final controller = ContactPickerController()..setToNew();
    addTearDown(controller.dispose);
    controller.contactType = ContactType.company;
    var notified = false;
    controller.addListener(() => notified = true);
    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    // Act
    controller.setGstRegistered(true);
    await tester.pump();

    // Assert
    expect(notified, isTrue);
    expect(controller.gstRegistered, isTrue);
  });
}
