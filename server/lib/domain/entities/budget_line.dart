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

/// A single monthly budget amount for one GL account within a budget year.
class BudgetLine {
  /// UUID of the general ledger account.
  final String generalLedgerId;

  /// Calendar month: 1 (January) through 12 (December).
  final int month;

  /// Budgeted amount in cents (always non-negative).
  final int amountCents;

  const BudgetLine({
    required this.generalLedgerId,
    required this.month,
    required this.amountCents,
  });
}
