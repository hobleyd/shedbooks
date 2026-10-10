import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shedbooks_client/utils/read_only_field.dart';

void main() {
  group('readOnlyDecoration', () {
    test('returns the decoration unchanged when the field is editable', () {
      // Arrange
      const InputDecoration decoration = InputDecoration(labelText: 'Name');

      // Act
      final InputDecoration result =
          readOnlyDecoration(decoration, readOnly: false);

      // Assert
      expect(result, same(decoration));
    });

    test('adds a grey fill and keeps the rest when the field is read-only',
        () {
      // Arrange
      const InputDecoration decoration = InputDecoration(labelText: 'Name');

      // Act
      final InputDecoration result =
          readOnlyDecoration(decoration, readOnly: true);

      // Assert
      expect(result.filled, isTrue);
      expect(result.fillColor, Colors.grey.shade100);
      expect(result.labelText, 'Name');
    });
  });

  testWidgets('text in a read-only field can be selected', (tester) async {
    // Arrange
    final TextEditingController controller =
        TextEditingController(text: 'Shed Inc');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: readOnlyDecoration(const InputDecoration(),
              readOnly: true),
        ),
      ),
    ));

    // Act — double-click selects the word under the pointer.
    final Offset word = tester.getTopLeft(find.byType(EditableText)) +
        const Offset(10, 10);
    await tester.tapAt(word);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(word);
    await tester.pumpAndSettle();

    // Assert
    expect(controller.selection.isCollapsed, isFalse);
    expect(controller.selection.textInside(controller.text), 'Shed');
  });
}
