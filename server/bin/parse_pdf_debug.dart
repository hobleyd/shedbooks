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
