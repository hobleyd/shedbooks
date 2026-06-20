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

/// Thrown when a member record is not found.
class MemberNotFoundException implements Exception {
  final String id;
  MemberNotFoundException(this.id);

  @override
  String toString() => 'Member not found: $id';

  String get message => 'Member not found: $id';
}

/// Thrown when member input fails validation.
class MemberValidationException implements Exception {
  final String message;
  const MemberValidationException(this.message);

  @override
  String toString() => 'MemberValidationException: $message';
}
