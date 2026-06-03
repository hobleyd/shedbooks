import 'package:flutter/material.dart';
import '../models/pnl_data.dart';
import '../models/transaction_entry.dart';

class PnlReportWidget extends StatefulWidget {
  final PnLData data;
  final String periodEndedLabel;

  const PnlReportWidget({
    super.key,
    required this.data,
    required this.periodEndedLabel,
  });

  @override
  State<PnlReportWidget> createState() => _PnlReportWidgetState();
}

class _PnlReportWidgetState extends State<PnlReportWidget> {
  final Set<String> _expandedGlIds = {};

  String _formatCents(int cents) {
    final double dollars = cents / 100;
    final List<String> parts = dollars.toStringAsFixed(2).split('.');
    final StringBuffer buf = StringBuffer();
    int c = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
      c++;
    }
    return '\$${buf.toString().split('').reversed.join()}.${parts[1]}';
  }

  String _formatDate(String iso) {
    final List<String> parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _toggleGl(String glId) {
    setState(() {
      if (_expandedGlIds.contains(glId)) {
        _expandedGlIds.remove(glId);
      } else {
        _expandedGlIds.add(glId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double labelColWidth = 80.0;
    const double amountWidth = 140.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.periodEndedLabel,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Income ──────────────────────────────────────────────────────
        _buildSectionHeader(context, 'Income', labelColWidth, amountWidth),
        const Divider(height: 1),
        if (widget.data.incomeLines.isEmpty)
          _buildEmptyRow(context, 'No income recorded for this period')
        else ...[
          ...widget.data.incomeLines.map((GlLine l) =>
              _buildGlRow(context, l, labelColWidth, amountWidth, isExpense: false)),
          _buildSubtotalRow(
              context, 'Total Income', widget.data.totalIncome, labelColWidth, amountWidth,
              isExpense: false),
        ],

        const SizedBox(height: 20),

        // ── Expenses ─────────────────────────────────────────────────────
        _buildSectionHeader(context, 'Expenses', labelColWidth, amountWidth),
        const Divider(height: 1),
        if (widget.data.expenseLines.isEmpty)
          _buildEmptyRow(context, 'No expenses recorded for this period')
        else ...[
          ...widget.data.expenseLines.map((GlLine l) =>
              _buildGlRow(context, l, labelColWidth, amountWidth, isExpense: true)),
          _buildSubtotalRow(
              context, 'Total Expenses', widget.data.totalExpenses, labelColWidth, amountWidth,
              isExpense: true),
        ],

        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 2),

        // ── Net ───────────────────────────────────────────────────────────
        _buildNetRow(context, widget.data.netProfit, labelColWidth, amountWidth),

        const SizedBox(height: 24),
        Text(
          '${widget.data.periodTransactions.length} transaction${widget.data.periodTransactions.length == 1 ? '' : 's'}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black38),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, double labelColWidth, double amountWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: labelColWidth,
            child: Text('Code',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.black45, fontSize: 10)),
          ),
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          SizedBox(
            width: amountWidth,
            child: Text('Amount',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 11),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildGlRow(BuildContext context, GlLine line, double labelColWidth,
      double amountWidth, {required bool isExpense}) {
    final bool isExpanded = _expandedGlIds.contains(line.gl.id);

    return Column(
      children: [
        InkWell(
          onTap: () => _toggleGl(line.gl.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: labelColWidth,
                  child: Text(
                    line.gl.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.gl.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: amountWidth,
                  child: Text(
                    isExpense
                        ? '(${_formatCents(line.totalCents)})'
                        : _formatCents(line.totalCents),
                    style: TextStyle(
                      color: isExpense ? Colors.red.shade700 : Colors.black87,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _buildTransactionPanel(context, line, isExpense),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  Widget _buildTransactionPanel(BuildContext context, GlLine line, bool isExpense) {
    final List<TransactionEntry> sorted = List<TransactionEntry>.from(line.transactions)
      ..sort((TransactionEntry a, TransactionEntry b) => a.transactionDate.compareTo(b.transactionDate));

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(84, 8, 8, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text('Date',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black45, fontSize: 10)),
                ),
                SizedBox(
                  width: 96,
                  child: Text('Receipt',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black45, fontSize: 10)),
                ),
                Expanded(
                  child: Text('Description',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black45, fontSize: 10)),
                ),
                SizedBox(
                  width: 120,
                  child: Text('Amount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.black45, fontSize: 10),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.3, indent: 84),
          ...sorted.map((TransactionEntry t) => _buildTransactionRow(context, t, isExpense)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, TransactionEntry t, bool isExpense) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(84, 5, 8, 5),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              _formatDate(t.transactionDate),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              t.receiptNumber,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              t.description.isEmpty ? '—' : t.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              isExpense
                  ? '(${_formatCents(t.totalAmount)})'
                  : _formatCents(t.totalAmount),
              style: TextStyle(
                fontSize: 12,
                color: isExpense ? Colors.red.shade700 : Colors.black87,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalRow(BuildContext context, String label, int cents,
      double labelColWidth, double amountWidth, {required bool isExpense}) {
    return Container(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withAlpha(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(width: labelColWidth),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            SizedBox(
              width: amountWidth,
              child: Text(
                isExpense
                    ? '(${_formatCents(cents)})'
                    : _formatCents(cents),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isExpense ? Colors.red.shade700 : Colors.black87,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // spacer to align with the chevron column
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNetRow(
      BuildContext context, int net, double labelColWidth, double amountWidth) {
    final bool isProfit = net >= 0;
    final Color color = isProfit ? Colors.black87 : Colors.red.shade700;
    final String label = isProfit ? 'Net Profit' : 'Net Loss';
    final String amount = isProfit
        ? _formatCents(net)
        : '(${_formatCents(net.abs())})';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: labelColWidth),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
            ),
          ),
          SizedBox(
            width: amountWidth,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRow(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(message,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black45, fontSize: 12)),
    );
  }
}
