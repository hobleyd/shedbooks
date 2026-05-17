import 'package:flutter/material.dart';

import '../models/transaction_entry.dart';

// ── Shared matching status ────────────────────────────────────────────────────

/// Matching status used by both the CSV import and PDF reconciliation screens.
/// [newTransaction] is only used by the import screen.
enum BankMatchStatus {
  autoMatched,
  amountMismatch,
  needsSelection,
  manuallyMatched,
  newTransaction,
  unmatched,
  skipped,
  alreadyImported,
}

extension BankMatchStatusX on BankMatchStatus {
  bool get needsAction =>
      this == BankMatchStatus.unmatched ||
      this == BankMatchStatus.needsSelection ||
      this == BankMatchStatus.amountMismatch;
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Formats [cents] as a dollar string, e.g. 12345 → "\$123.45".
String formatAmount(int cents) {
  final dollars = cents ~/ 100;
  final remainder = cents % 100;
  return '\$${dollars.toString()}.${remainder.toString().padLeft(2, '0')}';
}

/// Finds the subset of [records] whose [TransactionEntry.totalAmount] values
/// sum exactly to [target], or returns `null` if no exact match exists.
///
/// This handles both legitimate split line-items (multiple entries for the
/// same receipt, each with a different amount that together equal the bank
/// total) and duplicate full-amount entries (two entries for the same receipt
/// both carrying the full amount — only one is selected).
///
/// Uses bitmask enumeration: safe for up to 20 records (2^20 ≈ 1 M iterations).
/// Returns `null` for larger inputs rather than blocking.
List<TransactionEntry>? findMatchingSubset(
    List<TransactionEntry> records, int target) {
  final n = records.length;
  if (n > 20) return null;
  for (int mask = 1; mask < (1 << n); mask++) {
    int sum = 0;
    for (int i = 0; i < n; i++) {
      if ((mask >> i) & 1 == 1) sum += records[i].totalAmount;
    }
    if (sum == target) {
      return [
        for (int i = 0; i < n; i++)
          if ((mask >> i) & 1 == 1) records[i],
      ];
    }
  }
  return null;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

/// Icon + coloured label for a [BankMatchStatus].
class MatchStatusBadge extends StatelessWidget {
  final BankMatchStatus status;

  const MatchStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      BankMatchStatus.autoMatched => (
          'Matched',
          Icons.check_circle_outline,
          Colors.green,
        ),
      BankMatchStatus.manuallyMatched => (
          'Manual',
          Icons.handshake_outlined,
          Colors.blue,
        ),
      BankMatchStatus.newTransaction => (
          'New',
          Icons.add_circle_outline,
          Colors.teal,
        ),
      BankMatchStatus.amountMismatch => (
          'Mismatch',
          Icons.warning_amber_outlined,
          Colors.orange,
        ),
      BankMatchStatus.needsSelection => (
          'Select',
          Icons.help_outline,
          Colors.orange,
        ),
      BankMatchStatus.unmatched => (
          'Unmatched',
          Icons.cancel_outlined,
          Colors.red,
        ),
      BankMatchStatus.skipped => (
          'Skipped',
          Icons.remove_circle_outline,
          Colors.grey,
        ),
      BankMatchStatus.alreadyImported => (
          'Imported',
          Icons.check_circle,
          Colors.grey,
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// "Matched To" table cell: receipt numbers + optional amount-mismatch warning.
///
/// Pass [parsedReceipts] (receipts extracted from the description) to show a
/// hint when no transactions are matched yet.
class MatchedToCell extends StatelessWidget {
  final List<String> receipts;
  final int matchedTotal;
  final int bankAmount;
  final List<String> parsedReceipts;

  const MatchedToCell({
    super.key,
    required this.receipts,
    required this.matchedTotal,
    required this.bankAmount,
    required this.parsedReceipts,
  });

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      if (parsedReceipts.isNotEmpty) {
        return Text(parsedReceipts.join(', '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis);
      }
      return const SizedBox.shrink();
    }

    final mismatch = matchedTotal != bankAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(receipts.join(', '),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        if (mismatch)
          Text(
            'Sum ${formatAmount(matchedTotal)} ≠ bank ${formatAmount(bankAmount)}',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
          ),
      ],
    );
  }
}

/// Small icon + label indicator used in summary bars.
class SummaryIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const SummaryIndicator({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

// ── Manual match dialog ───────────────────────────────────────────────────────

/// Dialog for manually selecting one or more [TransactionEntry]s to match
/// against a bank row.
///
/// Returns the selected list on Apply, or null if cancelled (caller should
/// restore any previously released reserved IDs on null).
class ManualMatchDialog extends StatefulWidget {
  final String description;
  final String processDate;
  final int bankAmountCents;
  final List<TransactionEntry> candidates;
  final Map<String, String> contactNames;
  final Set<String> initialSelection;

  const ManualMatchDialog({
    super.key,
    required this.description,
    required this.processDate,
    required this.bankAmountCents,
    required this.candidates,
    required this.contactNames,
    required this.initialSelection,
  });

  @override
  State<ManualMatchDialog> createState() => _ManualMatchDialogState();
}

class _ManualMatchDialogState extends State<ManualMatchDialog> {
  late Set<String> _selected;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelection);
  }

  int get _selectedTotal => widget.candidates
      .where((t) => _selected.contains(t.id))
      .fold(0, (s, t) => s + t.totalAmount);

  bool get _totalsMatch => _selectedTotal == widget.bankAmountCents;

  List<TransactionEntry> get _filtered {
    if (_filter.isEmpty) return widget.candidates;
    final q = _filter.toLowerCase();
    return widget.candidates.where((t) {
      final name = (widget.contactNames[t.contactId] ?? '').toLowerCase();
      return t.receiptNumber.toLowerCase().contains(q) ||
          name.contains(q) ||
          t.transactionDate.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bankAmt = formatAmount(widget.bankAmountCents);
    final selAmt = formatAmount(_selectedTotal);
    final amtColor = _totalsMatch ? Colors.green : Colors.orange;
    final diff = (_selectedTotal - widget.bankAmountCents).abs();

    return AlertDialog(
      title: Text(
        'Match transaction',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: SizedBox(
        width: 600,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${widget.processDate}  '),
                Text('Bank: $bankAmt',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Text('Selected: $selAmt',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: amtColor)),
                if (!_totalsMatch && _selected.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Δ ${formatAmount(diff)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange.shade700),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Filter by receipt, contact or date',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.candidates.isEmpty
                  ? const Center(
                      child: Text('No unmatched transactions available.'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final t = _filtered[i];
                        final name =
                            widget.contactNames[t.contactId] ?? '';
                        return CheckboxListTile(
                          dense: true,
                          value: _selected.contains(t.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(t.id);
                            } else {
                              _selected.remove(t.id);
                            }
                          }),
                          title: Text(
                            '${t.receiptNumber}  '
                            '${formatAmount(t.totalAmount)}  '
                            '${t.transactionDate}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(name,
                              style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final result = widget.candidates
                .where((t) => _selected.contains(t.id))
                .toList();
            Navigator.of(context).pop(result);
          },
          child: Text(_selected.isEmpty ? 'Clear Match' : 'Apply'),
        ),
      ],
    );
  }
}
