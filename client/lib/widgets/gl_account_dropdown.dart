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

import '../models/general_ledger_entry.dart';

/// A dropdown for selecting a [GeneralLedgerEntry], styled consistently across
/// the app.
///
/// Renders inside an [InputDecorator] so it sits flush in form layouts.
/// Items are filtered to [directionFilter] when provided, sorted by their
/// full hierarchy path, depth-indented in the dropdown list, and annotated
/// with a GST badge when applicable.
///
/// Pass [compact] for the denser inline style (smaller icons, no GST badge).
class GlAccountDropdown extends StatelessWidget {
  /// All GL entries in the system — used for path building and depth calculation.
  final List<GeneralLedgerEntry> allEntries;

  /// Currently selected entry.
  final GeneralLedgerEntry? value;

  /// Called when the user selects an entry; null disables the dropdown.
  final ValueChanged<GeneralLedgerEntry?>? onChanged;

  /// Decoration for the outer [InputDecorator].
  final InputDecoration decoration;

  /// When set, only entries matching this direction are shown.
  /// Null means all entries are shown.
  final GlDirection? directionFilter;

  /// Use smaller icons and omit the GST badge for inline/compact layouts.
  final bool compact;

  const GlAccountDropdown({
    super.key,
    required this.allEntries,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.directionFilter,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = (directionFilter == null
            ? allEntries
            : allEntries.where((g) => g.direction == directionFilter).toList())
        ..sort((a, b) =>
            buildGlPath(allEntries, a.id).compareTo(buildGlPath(allEntries, b.id)));

    // Resolve the selection by id rather than trusting object identity:
    // [allEntries] may be a freshly-refetched list (e.g. after another
    // screen edited the GL accounts) containing new instances for the same
    // underlying account, which would otherwise fail DropdownButton's
    // "exactly one matching item" check.
    final resolvedValue = value == null
        ? null
        : filtered.where((g) => g.id == value!.id).isEmpty
            ? null
            : filtered.where((g) => g.id == value!.id).first;

    final double iconSize = compact ? 14 : 16;
    final double spacing = compact ? 4 : 8;

    return InputDecorator(
      decoration: decoration,
      child: DropdownButton<GeneralLedgerEntry>(
        value: resolvedValue,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        hint: const Text('Select account', style: TextStyle(fontSize: 13)),
        selectedItemBuilder: (context) => filtered.map((gl) {
          final isIn = gl.direction == GlDirection.moneyIn;
          return Row(children: [
            Icon(
              isIn
                  ? Icons.arrow_circle_down_outlined
                  : Icons.arrow_circle_up_outlined,
              size: iconSize,
              color: isIn ? Colors.green.shade700 : Colors.red.shade700,
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Text(
                buildGlPath(allEntries, gl.id),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (!compact && gl.gstApplicable) ...[
              SizedBox(width: spacing),
              _GstBadge(),
            ],
          ]);
        }).toList(),
        items: filtered.map((gl) {
          final isIn = gl.direction == GlDirection.moneyIn;
          final depth = glDepth(allEntries, gl.id);
          return DropdownMenuItem(
            value: gl,
            child: Padding(
              padding: EdgeInsets.only(left: depth * 16.0),
              child: Row(children: [
                Icon(
                  isIn
                      ? Icons.arrow_circle_down_outlined
                      : Icons.arrow_circle_up_outlined,
                  size: iconSize,
                  color: isIn ? Colors.green.shade700 : Colors.red.shade700,
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Text(
                    gl.description,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (!compact && gl.gstApplicable) ...[
                  SizedBox(width: spacing),
                  _GstBadge(),
                ],
              ]),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _GstBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        'GST',
        style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
      ),
    );
  }
}
