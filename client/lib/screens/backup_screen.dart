// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

/// Admin screen for database backup and restore.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _backupBusy = false;
  bool _restoreBusy = false;
  String? _message;
  bool _messageIsError = false;

  // ── Backup ─────────────────────────────────────────────────────────────────

  Future<void> _backup() async {
    setState(() {
      _backupBusy = true;
      _message = null;
    });
    try {
      final res = await context.read<ApiClient>().get('/admin/backup');
      if (!mounted) return;

      if (res.statusCode != 200) {
        String err = 'Backup failed (${res.statusCode})';
        try {
          err = (jsonDecode(res.body) as Map)['error'] as String? ?? err;
        } catch (_) {}
        _setMessage(err, isError: true);
        return;
      }

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'shedbooks-backup-$stamp.json';

      final blob = html.Blob([res.bodyBytes], 'application/octet-stream');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);

      _setMessage('Backup downloaded: $filename');
    } catch (e) {
      if (mounted) _setMessage('Backup error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _setMessage('Could not read file', isError: true);
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore database?'),
        content: Text(
          'This will overwrite all current data with the contents of '
          '"${file.name}".\n\nThis cannot be undone. '
          'Make sure you have a current backup before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _restoreBusy = true;
      _message = null;
    });
    try {
      final res =
          await context.read<ApiClient>().postBytes('/admin/restore', bytes);
      if (!mounted) return;

      if (res.statusCode == 200) {
        _setMessage('Restore completed successfully');
      } else {
        String err = 'Restore failed (${res.statusCode})';
        try {
          err = (jsonDecode(res.body) as Map)['error'] as String? ?? err;
        } catch (_) {}
        _setMessage(err, isError: true);
      }
    } catch (e) {
      if (mounted) _setMessage('Restore error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  void _setMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = msg;
      _messageIsError = isError;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _backupBusy || _restoreBusy;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Database Backup',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Create a full database backup or restore from a previous backup file.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 32),

          // Warning banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Restoring a backup overwrites all current data and cannot '
                    'be undone. Always take a fresh backup before restoring.',
                    style: TextStyle(color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Backup card
          _buildActionCard(
            icon: Icons.cloud_download_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Backup',
            subtitle:
                'Download a complete SQL dump of the database to your computer.',
            button: FilledButton.icon(
              onPressed: busy ? null : _backup,
              icon: _backupBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined, size: 18),
              label: const Text('Backup'),
            ),
          ),
          const SizedBox(height: 16),

          // Restore card
          _buildActionCard(
            icon: Icons.cloud_upload_outlined,
            iconColor: Theme.of(context).colorScheme.error,
            title: 'Restore',
            subtitle:
                'Select a .sql backup file to restore. All current data will be replaced.',
            button: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: busy ? null : _restore,
              icon: _restoreBusy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.error))
                  : const Icon(Icons.upload_outlined, size: 18),
              label: const Text('Restore'),
            ),
          ),

          if (_message != null) ...[
            const SizedBox(height: 24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _messageIsError
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _messageIsError
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _messageIsError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: _messageIsError
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _messageIsError
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget button,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            button,
          ],
        ),
      ),
    );
  }
}
