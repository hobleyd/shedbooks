import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/pnl_data.dart';

class PnlReportWidget extends StatelessWidget {
  final PnLData data;
  final String periodEndedLabel;

  const PnlReportWidget({
    super.key,
    required this.data,
    required this.periodEndedLabel,
  });

  String _formatCents(int cents) {
    final dollars = cents / 100;
    final parts = dollars.toStringAsFixed(2).split('.');
    final buf = StringBuffer();
    int c = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
      c++;
    }
    return '\$${buf.toString().split('').reversed.join()}.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    const labelColWidth = 80.0;
    const amountWidth = 140.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          periodEndedLabel,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        // ── Income ──────────────────────────────────────────────────────
        _buildSectionHeader(context, 'Income', labelColWidth, amountWidth),
        const Divider(height: 1),
        if (data.incomeLines.isEmpty)
          _buildEmptyRow(context, 'No income recorded for this period')
        else ...[
          ...data.incomeLines.map((l) =>
              _buildGlRow(context, l, labelColWidth, amountWidth, isExpense: false)),
          _buildSubtotalRow(
              context, 'Total Income', data.totalIncome, labelColWidth, amountWidth,
              isExpense: false),
        ],

        const SizedBox(height: 20),

        // ── Expenses ─────────────────────────────────────────────────────
        _buildSectionHeader(context, 'Expenses', labelColWidth, amountWidth),
        const Divider(height: 1),
        if (data.expenseLines.isEmpty)
          _buildEmptyRow(context, 'No expenses recorded for this period')
        else ...[
          ...data.expenseLines.map((l) =>
              _buildGlRow(context, l, labelColWidth, amountWidth, isExpense: true)),
          _buildSubtotalRow(
              context, 'Total Expenses', data.totalExpenses, labelColWidth, amountWidth,
              isExpense: true),
        ],

        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 2),

        // ── Net ───────────────────────────────────────────────────────────
        _buildNetRow(context, data.netProfit, labelColWidth, amountWidth),

        const SizedBox(height: 24),
        Text(
          '${data.periodTransactions.length} transaction${data.periodTransactions.length == 1 ? '' : 's'}',
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
    return Column(
      children: [
        Padding(
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
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
      ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildNetRow(
      BuildContext context, int net, double labelColWidth, double amountWidth) {
    final isProfit = net >= 0;
    final color = isProfit ? Colors.black87 : Colors.red.shade700;
    final label = isProfit ? 'Net Profit' : 'Net Loss';
    final amount = isProfit
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
