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

/// Returns a field-level diff between [before] and [after] maps.
///
/// Only fields whose string representation changed are included in the result.
/// Each changed field maps to `{'from': oldValue, 'to': newValue}`.
Map<String, dynamic> diffMaps(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final result = <String, dynamic>{};
  for (final key in after.keys) {
    final b = before[key];
    final a = after[key];
    if (b?.toString() != a?.toString()) {
      result[key] = {'from': b, 'to': a};
    }
  }
  return result;
}
