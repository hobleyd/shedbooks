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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

/// Dialog that allows contributors and administrators to manage their API key.
///
/// The API key is used to authenticate CardDAV clients (e.g. iOS Contacts)
/// that cannot carry JWT Bearer tokens.  The raw key is shown only once
/// immediately after generation; it cannot be recovered afterwards.
class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key});

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

enum _Phase { loading, status, generated, error }

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  _Phase _phase = _Phase.loading;
  bool _hasKey = false;
  String _username = '';
  String _generatedKey = '';
  String _errorMessage = '';
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final client = context.read<ApiClient>();
      final res = await client.get('/api-key');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _hasKey = data['hasKey'] as bool? ?? false;
          _username = data['username'] as String? ?? '';
          _phase = _Phase.status;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load API key status (${res.statusCode})';
          _phase = _Phase.error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load API key status';
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final client = context.read<ApiClient>();
      final res = await client.post('/api-key/generate', '{}');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _generatedKey = data['apiKey'] as String? ?? '';
          _username = data['username'] as String? ?? _username;
          _phase = _Phase.generated;
          _generating = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to generate API key (${res.statusCode})';
          _phase = _Phase.error;
          _generating = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate API key';
        _phase = _Phase.error;
        _generating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Key'),
      content: SizedBox(
        width: 420,
        child: _buildContent(context),
      ),
      actions: _buildActions(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_phase) {
      _Phase.loading => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
        ),
      _Phase.error => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(_errorMessage),
          ],
        ),
      _Phase.status => _buildStatusContent(context),
      _Phase.generated => _buildGeneratedContent(context),
    };
  }

  Widget _buildStatusContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use an API key to connect CardDAV clients such as iOS Contacts.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _LabeledField(label: 'Username', value: _username),
        const SizedBox(height: 8),
        if (_hasKey) ...[
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'Active API key exists',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Regenerating will invalidate the current key immediately.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ] else ...[
          Text(
            'No API key exists yet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildGeneratedContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Copy this key now — it will not be shown again.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(label: 'Username', value: _username),
        const SizedBox(height: 12),
        _CopyableField(label: 'API Key', value: _generatedKey),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return switch (_phase) {
      _Phase.loading || _Phase.error => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      _Phase.status => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: _generating ? null : _generate,
            child: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_hasKey ? 'Regenerate Key' : 'Generate Key'),
          ),
        ],
      _Phase.generated => [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
    };
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class _CopyableField extends StatelessWidget {
  final String label;
  final String value;

  const _CopyableField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlpha(80),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy to clipboard',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API key copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
