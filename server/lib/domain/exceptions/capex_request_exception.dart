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

/// Thrown when a capex request record is not found.
class CapexRequestNotFoundException implements Exception {
  final String id;
  CapexRequestNotFoundException(this.id);

  @override
  String toString() => 'Capex request not found: $id';

  String get message => 'Capex request not found: $id';
}

/// Thrown when capex request input fails validation.
class CapexRequestValidationException implements Exception {
  final String message;
  const CapexRequestValidationException(this.message);

  @override
  String toString() => 'CapexRequestValidationException: $message';
}
