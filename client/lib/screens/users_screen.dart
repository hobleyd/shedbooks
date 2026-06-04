import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

const _activeThreshold = Duration(minutes: 30);

class _UserPresence {
  final String userId;
  final String userEmail;
  final String role;
  final DateTime lastSeen;
  final String ipAddress;

  const _UserPresence({
    required this.userId,
    required this.userEmail,
    required this.role,
    required this.lastSeen,
    required this.ipAddress,
  });

  factory _UserPresence.fromJson(Map<String, dynamic> j) => _UserPresence(
        userId: j['userId'] as String? ?? '',
        userEmail: j['userEmail'] as String? ?? '',
        role: j['role'] as String? ?? '',
        lastSeen: DateTime.parse(j['lastSeen'] as String),
        ipAddress: j['ipAddress'] as String? ?? '',
      );

  bool get isActive =>
      DateTime.now().toUtc().difference(lastSeen.toUtc()) < _activeThreshold;
}

/// Admin screen showing all users who have accessed the application,
/// grouped by entity. Only accessible to administrators.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<_UserPresence> _users = [];
  String? _entityName;
  bool _busy = false;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final client = context.read<ApiClient>();
      final results = await Future.wait([
        client.get('/admin/users'),
        client.get('/entity-details'),
      ]);

      if (!mounted) return;

      final usersRes = results[0];
      final entityRes = results[1];

      if (usersRes.statusCode != 200) {
        setState(() => _error = 'Failed to load users (${usersRes.statusCode})');
        return;
      }

      final body = jsonDecode(usersRes.body) as Map<String, dynamic>;
      String? entityName;
      if (entityRes.statusCode == 200) {
        final entityBody = jsonDecode(entityRes.body) as Map<String, dynamic>;
        entityName = entityBody['name'] as String?;
      }

      setState(() {
        _users = (body['users'] as List)
            .cast<Map<String, dynamic>>()
            .map(_UserPresence.fromJson)
            .toList();
        _entityName = entityName;
        _lastRefreshed = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Users',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Users who have accessed the application, grouped by entity. '
                      'Active = last seen within 30 minutes.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildRefreshButton(),
            ],
          ),
          if (_lastRefreshed != null) ...[
            const SizedBox(height: 4),
            Text(
              'Refreshed at ${_formatTime(_lastRefreshed!)} · auto-refreshes every 30 s',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black38),
            ),
          ],
          const SizedBox(height: 24),
          if (_error != null) _buildError(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _load,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 18),
      label: const Text('Refresh'),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildContent() {
    if (_busy && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No users have accessed the application yet.',
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      );
    }

    final groupName = _entityName ?? 'Entity';
    final activeCount = _users.where((u) => u.isActive).length;

    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGroupHeader(groupName, activeCount),
            const Divider(height: 1),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String entityName, int activeCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.business_outlined, size: 20),
          const SizedBox(width: 8),
          Text(
            entityName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '$activeCount active',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_users.length} total',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 40,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Last Seen')),
          DataColumn(label: Text('IP Address')),
        ],
        rows: _users.map(_buildRow).toList(),
      ),
    );
  }

  DataRow _buildRow(_UserPresence u) {
    return DataRow(cells: [
      DataCell(_buildStatusDot(u.isActive)),
      DataCell(_buildUserCell(u)),
      DataCell(_buildRoleBadge(u.role)),
      DataCell(Text(
        _formatDateTime(u.lastSeen),
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
      )),
      DataCell(Text(
        u.ipAddress.isNotEmpty ? u.ipAddress : '—',
        style: const TextStyle(fontSize: 13),
      )),
    ]);
  }

  Widget _buildStatusDot(bool active) {
    return Tooltip(
      message: active ? 'Active (last 30 min)' : 'Inactive',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.green.shade500 : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildUserCell(_UserPresence u) {
    if (u.userEmail.isNotEmpty) {
      return Tooltip(
        message: u.userId,
        child: Text(
          u.userEmail,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      );
    }
    final sub = u.userId;
    final atIndex = sub.indexOf('|');
    final shortSub = atIndex >= 0 && sub.length > atIndex + 9
        ? sub.substring(atIndex + 1, atIndex + 9)
        : sub;
    return Tooltip(
      message: sub,
      child: Text(
        'user:$shortSub',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 12, fontFamily: 'monospace', color: Colors.black54),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final (bg, fg) = switch (role) {
      'administrator' => (Colors.purple.shade50, Colors.purple.shade800),
      'contributor' => (Colors.blue.shade50, Colors.blue.shade800),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
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

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }
}
