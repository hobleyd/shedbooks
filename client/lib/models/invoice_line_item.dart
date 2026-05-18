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

  void updateAmounts(double gstRate) {
    final amountText = amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText) ?? 0.0;
    amountCents = (amount * 100).round();
    
    if (glAccount?.gstApplicable == true) {
      // GST is included in the amount
      gstCents = (amountCents * gstRate / (1 + gstRate)).round();
    } else {
      gstCents = 0;
    }
  }
}
