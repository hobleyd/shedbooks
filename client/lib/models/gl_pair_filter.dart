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

import 'general_ledger_entry.dart';

/// Passed as route extra when navigating to /transactions from the Special
/// Initiatives widget — carries both the income and expense GL so the
/// transactions screen can show all activity for the initiative.
class GlPairFilter {
  final GeneralLedgerEntry incomeGl;
  final GeneralLedgerEntry expenseGl;

  const GlPairFilter({required this.incomeGl, required this.expenseGl});
}
