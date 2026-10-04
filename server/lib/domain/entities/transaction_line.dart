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

/// One general ledger line of a split transaction — the part of a payment
/// that is coded to a single general ledger account.
class TransactionLine {
  /// FK — the general ledger account this line is coded to.
  final String generalLedgerId;

  /// Line value in cents, excluding GST (always positive).
  final int amount;

  /// GST component of the line in cents (0 when GST does not apply).
  final int gstAmount;

  /// Optional free-text description for this line.
  final String description;

  const TransactionLine({
    required this.generalLedgerId,
    required this.amount,
    required this.gstAmount,
    this.description = '',
  });
}
