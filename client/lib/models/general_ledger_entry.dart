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

/// Whether a general ledger account records inflows or outflows.
enum GlDirection { moneyIn, moneyOut }

/// A general ledger account entry returned from the API.
class GeneralLedgerEntry {
  final String id;
  final String label;
  final String description;
  final bool gstApplicable;
  final GlDirection direction;

  /// Parent account ID; null for top-level accounts.
  final String? parentId;

  const GeneralLedgerEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    this.parentId,
  });

  factory GeneralLedgerEntry.fromJson(Map<String, dynamic> json) {
    return GeneralLedgerEntry(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      gstApplicable: json['gstApplicable'] as bool,
      direction: json['direction'] == 'moneyIn' ? GlDirection.moneyIn : GlDirection.moneyOut,
      parentId: json['parentId'] as String?,
    );
  }
}

/// Builds the full display path for [id] by walking the parent chain.
///
/// Example: given accounts [Fundraising, Recycling (child of Fundraising)],
/// returns "Fundraising > Recycling" for the Recycling account id.
String buildGlPath(List<GeneralLedgerEntry> all, String id) {
  final byId = {for (final g in all) g.id: g};
  final parts = <String>[];
  GeneralLedgerEntry? current = byId[id];
  while (current != null) {
    parts.insert(0, current.description);
    current = current.parentId != null ? byId[current.parentId!] : null;
  }
  if (parts.isEmpty) return id;
  return parts.join(' > ');
}

/// Returns the depth of [id] in the account hierarchy (0 = top-level).
int glDepth(List<GeneralLedgerEntry> all, String id) {
  final byId = {for (final g in all) g.id: g};
  int depth = 0;
  GeneralLedgerEntry? current = byId[id];
  while (current?.parentId != null) {
    depth++;
    current = byId[current!.parentId!];
  }
  return depth;
}

/// Orders [accounts] so children are grouped immediately after their parent
/// (recursively), with siblings at every level — including the top level —
/// sorted by [GeneralLedgerEntry.label]. An account whose parent isn't
/// present in [accounts] (e.g. filtered out by direction beforehand) is
/// treated as a root rather than dropped, so callers can safely sort an
/// already direction-filtered subset.
List<GeneralLedgerEntry> sortGlHierarchically(List<GeneralLedgerEntry> accounts) {
  final ids = accounts.map((g) => g.id).toSet();
  final byParent = <String?, List<GeneralLedgerEntry>>{};
  for (final g in accounts) {
    final parentKey =
        (g.parentId != null && ids.contains(g.parentId)) ? g.parentId : null;
    byParent.putIfAbsent(parentKey, () => []).add(g);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.label.compareTo(b.label));
  }

  final result = <GeneralLedgerEntry>[];
  void visit(GeneralLedgerEntry g) {
    result.add(g);
    for (final child in byParent[g.id] ?? const []) {
      visit(child);
    }
  }
  for (final root in byParent[null] ?? const []) {
    visit(root);
  }
  return result;
}
