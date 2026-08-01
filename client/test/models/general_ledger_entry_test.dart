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
import 'package:shedbooks_client/models/general_ledger_entry.dart';

GeneralLedgerEntry _gl(String id, String label, {String? parentId}) =>
    GeneralLedgerEntry(
      id: id,
      label: label,
      description: label,
      gstApplicable: false,
      direction: GlDirection.moneyOut,
      parentId: parentId,
    );

void main() {
  group('sortGlHierarchically', () {
    test('sorts top-level accounts by label', () {
      final accounts = [_gl('a', 'Zebra'), _gl('b', 'Apple'), _gl('c', 'Mango')];
      final sorted = sortGlHierarchically(accounts);
      expect(sorted.map((g) => g.label), ['Apple', 'Mango', 'Zebra']);
    });

    test('groups children immediately after their parent, regardless of input order', () {
      // Input deliberately interleaved and out of label order.
      final accounts = [
        _gl('child-b', 'Recycling', parentId: 'parent'),
        _gl('other', 'Zzz'),
        _gl('parent', 'Fundraising'),
        _gl('child-a', 'Easter Fair', parentId: 'parent'),
      ];
      final sorted = sortGlHierarchically(accounts);
      expect(sorted.map((g) => g.id), ['parent', 'child-a', 'child-b', 'other']);
    });

    test('sorts children by label within a parent, independent of siblings', () {
      final accounts = [
        _gl('parent', 'Fundraising'),
        _gl('c2', 'Zzz Sub', parentId: 'parent'),
        _gl('c1', 'Aaa Sub', parentId: 'parent'),
      ];
      final sorted = sortGlHierarchically(accounts);
      expect(sorted.map((g) => g.id), ['parent', 'c1', 'c2']);
    });

    test('supports multiple levels of nesting', () {
      final accounts = [
        _gl('grandchild', 'Leaf', parentId: 'child'),
        _gl('root', 'Root'),
        _gl('child', 'Middle', parentId: 'root'),
      ];
      final sorted = sortGlHierarchically(accounts);
      expect(sorted.map((g) => g.id), ['root', 'child', 'grandchild']);
    });

    test('treats an account whose parent was filtered out as a root instead of dropping it', () {
      // Simulates a direction-filtered subset where the parent belongs to
      // the other direction and isn't present in [accounts].
      final accounts = [_gl('orphan', 'Orphan', parentId: 'missing-parent')];
      final sorted = sortGlHierarchically(accounts);
      expect(sorted.map((g) => g.id), ['orphan']);
    });
  });
}
