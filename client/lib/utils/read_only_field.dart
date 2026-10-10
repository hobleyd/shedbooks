import 'package:flutter/material.dart';

/// Returns [decoration] styled for a text field whose value is shown but
/// cannot be edited.
///
/// Such fields are `readOnly` rather than disabled, because the text of a
/// disabled field cannot be selected or copied. A read-only field keeps the
/// enabled look, so this adds a grey fill to show that it is locked. When
/// [readOnly] is false the decoration is returned unchanged.
InputDecoration readOnlyDecoration(
  InputDecoration decoration, {
  required bool readOnly,
}) {
  if (!readOnly) return decoration;
  return decoration.copyWith(filled: true, fillColor: Colors.grey.shade100);
}
