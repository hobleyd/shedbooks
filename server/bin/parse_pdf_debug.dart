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

import 'dart:io';
import '../lib/infrastructure/pdf/cba_statement_parser.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : '/Users/david.hobley/Downloads/2026-01 Operating Account.pdf';
  final bytes = File(path).readAsBytesSync();
  final data = CbaStatementParser.parse(bytes);
  if (data == null) { print('PARSE FAILED'); return; }
  print('Period: ${data.statementPeriod}');
  print('Opening: \$${(data.openingBalanceCents/100).toStringAsFixed(2)}  Closing: \$${(data.closingBalanceCents/100).toStringAsFixed(2)}');
  print('${data.transactions.length} transactions:\n');
  for (final t in data.transactions) {
    final dir = t.isDebit ? 'DR' : 'CR';
    print('${t.date} $dir \$${(t.amountCents/100).toStringAsFixed(2).padLeft(10)} | ${t.description}');
  }
}
