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

/// A mapping from an external (legacy) GL code to a current GL account UUID.
///
/// Stored per entity so CSV imports can auto-match previously confirmed mappings.
class BudgetGlMapping {
  /// Auth0 org ID of the owning entity.
  final String entityId;

  /// Account code from the external/legacy system.
  final String externalCode;

  /// Human-readable name from the external system.
  final String externalName;

  /// UUID of the matching GL account in this system.
  final String generalLedgerId;

  const BudgetGlMapping({
    required this.entityId,
    required this.externalCode,
    required this.externalName,
    required this.generalLedgerId,
  });
}
