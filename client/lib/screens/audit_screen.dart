import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

class _AuditEntry {
  final String id;
  final String userEmail;
  final String userId;
  final String ipAddress;
  final String action;
  final String tableName;
  final String? recordId;
  final String method;
  final String path;
  final int statusCode;
  final DateTime createdAt;

  const _AuditEntry({
    required this.id,
    required this.userEmail,
    required this.userId,
    required this.ipAddress,
    required this.action,
    required this.tableName,
    this.recordId,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.createdAt,
  });

  factory _AuditEntry.fromJson(Map<String, dynamic> j) => _AuditEntry(
        id: j['id'] as String? ?? '',
        userEmail: j['userEmail'] as String? ?? '',
        userId: j['userId'] as String? ?? '',
        ipAddress: j['ipAddress'] as String? ?? '',
        action: j['action'] as String? ?? '',
        tableName: j['tableName'] as String? ?? '',
        recordId: j['recordId'] as String?,
        method: j['method'] as String? ?? '',
        path: j['path'] as String? ?? '',
        statusCode: j['statusCode'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Admin screen showing a paginated, searchable audit log.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<_AuditEntry> _entries = [];
  int _total = 0;
  int _page = 1;
  int _limit = 100;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _page = 1);
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final search = _searchController.text.trim();
      final query = [
        'page=$_page',
        if (search.isNotEmpty) 'search=${Uri.encodeQueryComponent(search)}',
      ].join('&');

      final res = await context
          .read<ApiClient>()
          .get('/admin/audit-log?$query');

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => _error = 'Failed to load audit log (${res.statusCode})');
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _entries = (body['entries'] as List)
            .cast<Map<String, dynamic>>()
            .map(_AuditEntry.fromJson)
            .toList();
        _total = body['total'] as int;
        _limit = body['limit'] as int? ?? 100;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goPage(int page) {
    setState(() => _page = page);
    _load();
  }

  int get _totalPages => _total == 0 ? 1 : ((_total + _limit - 1) ~/ _limit);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audit Log',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'A record of all changes made through the API.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _buildSearchBar(),
          const SizedBox(height: 16),
          if (_error != null) _buildError(),
          Expanded(child: _buildTable()),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by user, IP, action, table, record ID…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(_error!,
            style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
      ),
    );
  }

  Widget _buildTable() {
    if (_busy && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No audit entries yet.'
              : 'No entries match your search.',
          style: const TextStyle(color: Colors.black45),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 36,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Date / Time')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('IP Address')),
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('Table')),
                DataColumn(label: Text('Record ID')),
              ],
              rows: _entries.map(_buildRow).toList(),
            ),
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  DataRow _buildRow(_AuditEntry e) {
    final label = e.userEmail.isNotEmpty ? e.userEmail : e.userId;
    final shortId = e.recordId != null && e.recordId!.length > 8
        ? e.recordId!.substring(0, 8)
        : e.recordId ?? '—';

    return DataRow(cells: [
      DataCell(Text(_formatDateTime(e.createdAt),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
      DataCell(
        Tooltip(
          message: e.userId,
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
        ),
      ),
      DataCell(Text(e.ipAddress.isNotEmpty ? e.ipAddress : '—',
          style: const TextStyle(fontSize: 13))),
      DataCell(_buildActionBadge(e.action)),
      DataCell(Text(e.tableName, style: const TextStyle(fontSize: 13))),
      DataCell(
        e.recordId != null
            ? Tooltip(
                message: e.recordId!,
                child: Text(shortId,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace')),
              )
            : const Text('—', style: TextStyle(fontSize: 13)),
      ),
    ]);
  }

  Widget _buildActionBadge(String action) {
    final (bg, fg) = switch (action) {
      'CREATE' => (Colors.green.shade50, Colors.green.shade800),
      'UPDATE' => (Colors.blue.shade50, Colors.blue.shade800),
      'DELETE' => (Colors.red.shade50, Colors.red.shade800),
      'MERGE' => (Colors.purple.shade50, Colors.purple.shade800),
      'BACKUP' => (Colors.amber.shade50, Colors.amber.shade800),
      'RESTORE' => (Colors.orange.shade50, Colors.orange.shade800),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(action,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildPagination() {
    final from = _total == 0 ? 0 : (_page - 1) * _limit + 1;
    final to = (_page * _limit).clamp(0, _total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _total == 0
              ? 'No results'
              : 'Showing $from–$to of $_total',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _page > 1 && !_busy
                  ? () => _goPage(_page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('Previous'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Page $_page of $_totalPages',
                  style: const TextStyle(fontSize: 13)),
            ),
            TextButton.icon(
              onPressed: _page < _totalPages && !_busy
                  ? () => _goPage(_page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final t =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
