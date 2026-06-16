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

/// Mutable holder for field-level change data captured during a request.
///
/// Injected into the Shelf request context by the audit middleware under the
/// key `'audit.changes'` before the inner handler is called.  Handlers may
/// call [set] to attach change details that will be persisted alongside the
/// audit entry.  If [set] is never called the entry is stored without change
/// details.
class AuditChanges {
  Map<String, dynamic>? _data;

  /// Attaches [data] to be stored in the audit log entry.
  void set(Map<String, dynamic> data) => _data = data;

  /// The attached change data, or null if [set] was never called.
  Map<String, dynamic>? get data => _data;
}
