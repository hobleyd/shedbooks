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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/asset_entry.dart';
import '../models/entity_details.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../widgets/asset_pdf_report.dart';
import '../widgets/pdf_report_components.dart';

/// Asset value report — summarises estimated market value by section.
class AssetReportScreen extends StatefulWidget {
  const AssetReportScreen({super.key});

  @override
  State<AssetReportScreen> createState() => _AssetReportScreenState();
}

class _AssetReportScreenState extends State<AssetReportScreen> {
  bool _loading = true;
  String? _loadError;
  List<AssetEntry> _assets = [];
  EntityDetails? _entityDetails;
  bool _includeFullRegister = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/assets'),
        client.get('/entity-details'),
      ]);
      if (!mounted) return;

      if (results[0].statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load assets (${results[0].statusCode})';
          _loading = false;
        });
        return;
      }

      final assets = (jsonDecode(results[0].body) as List)
          .map((e) => AssetEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      EntityDetails? entityDetails;
      if (results[1].statusCode == 200) {
        entityDetails = EntityDetails.fromJson(
            jsonDecode(results[1].body) as Map<String, dynamic>);
      }

      setState(() {
        _assets = assets;
        _entityDetails = entityDetails;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  List<AssetSectionSummary> get _sections =>
      AssetSectionSummary.fromAssets(_assets);

  // ── PDF generation ─────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    final sections = _sections;
    final entity = _entityDetails;
    final generated = Formatters.formatDateShort(DateTime.now());

    final doc = pw.Document(title: 'Asset Register');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 50),
      header: (ctx) {
        if (ctx.pageNumber == 1) return pw.SizedBox(height: 0);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${entity?.name ?? ''} - Asset Register (continued)',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
          ],
        );
      },
      footer: (ctx) => PdfReportComponents.pageFooter(ctx, generated),
      build: (ctx) => [
        PdfReportComponents.entityHeader(entity),
        ...AssetPdfReport.build(
          sections: sections,
          allAssets: _assets,
          includeFullRegister: _includeFullRegister,
          formatCents: Formatters.formatCents,
          asOf: generated,
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            _buildError()
          else
            Expanded(
              child: SingleChildScrollView(child: _buildReport()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text('Assets', style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        if (!_loading) ...[
          OutlinedButton.icon(
            onPressed: _generatePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final sections = _sections;
    final totalCount = sections.fold(0, (sum, s) => sum + s.count);
    final totalCents = sections.fold(0, (sum, s) => sum + s.totalCents);
    final asOf = Formatters.formatDateShort(DateTime.now());

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asset Register Summary',
              style: Theme.of(context).textTheme.titleLarge),
          Text('As at $asOf',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 16),

          // Header row
          _tableHeader(context),
          const Divider(height: 1, thickness: 1),

          // Section rows
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No assets recorded.',
                  style: Theme.of(context).textTheme.bodySmall),
            )
          else ...[
            ...sections.expand((s) => [
                  _sectionRow(context, s),
                  const Divider(height: 1),
                ]),

            // Grand total
            const Divider(height: 1, thickness: 2),
            _totalRow(context, totalCount, totalCents),
          ],

          const SizedBox(height: 28),

          // PDF option
          Row(
            children: [
              Checkbox(
                value: _includeFullRegister,
                onChanged: (v) =>
                    setState(() => _includeFullRegister = v ?? false),
              ),
              const SizedBox(width: 4),
              const Text('Include full Asset Register in PDF'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text('Section', style: style)),
          SizedBox(
              width: 80,
              child:
                  Text('Assets', style: style, textAlign: TextAlign.right)),
          SizedBox(
              width: 140,
              child:
                  Text('Est. Value', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _sectionRow(BuildContext context, AssetSectionSummary s) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(s.section, style: bodyStyle)),
          SizedBox(
            width: 80,
            child: Text('${s.count}',
                style: bodyStyle, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 140,
            child: Text(
              s.hasValue ? Formatters.formatCents(s.totalCents) : '—',
              style: bodyStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, int count, int totalCents) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontWeight: FontWeight.bold);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text('Total', style: style)),
          SizedBox(
              width: 80,
              child:
                  Text('$count', style: style, textAlign: TextAlign.right)),
          SizedBox(
              width: 140,
              child: Text(Formatters.formatCents(totalCents),
                  style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
