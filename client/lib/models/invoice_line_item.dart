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

import 'package:flutter/material.dart';
import '../models/general_ledger_entry.dart';

class InvoiceLineItem {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  GeneralLedgerEntry? glAccount;
  int amountCents = 0;
  int gstCents = 0;

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
  }

  void updateAmounts(double gstRate, {bool contactGstRegistered = false}) {
    final amountText = amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText) ?? 0.0;
    amountCents = (amount * 100).round();

    if (contactGstRegistered) {
      gstCents = (amountCents * gstRate).round();
    } else {
      gstCents = 0;
    }
  }
}
