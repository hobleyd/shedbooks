import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../models/entity_details.dart';
import '../services/api_client.dart';
import '../utils/receipt_format.dart';

/// Admin screen for viewing and editing entity identity details.
class EntityScreen extends StatefulWidget {
  const EntityScreen({super.key});

  @override
  State<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends State<EntityScreen> {
  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  EntityDetails? _saved;
  bool _editing = false;

  final _nameController = TextEditingController();
  final _abnController = TextEditingController();
  final _incorporationController = TextEditingController();
  final _apcaIdController = TextEditingController();
  final _moneyInReceiptFormatController = TextEditingController();
  final _moneyOutReceiptFormatController = TextEditingController();

  bool get _isCreating => _saved == null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _abnController.addListener(_onFieldChanged);
    _incorporationController.addListener(_onFieldChanged);
    _apcaIdController.addListener(_onFieldChanged);
    _moneyInReceiptFormatController.addListener(_onFieldChanged);
    _moneyOutReceiptFormatController.addListener(_onFieldChanged);
    _load();
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _abnController.dispose();
    _incorporationController.dispose();
    _apcaIdController.dispose();
    _moneyInReceiptFormatController.dispose();
    _moneyOutReceiptFormatController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await context.read<ApiClient>().get('/entity-details');
      if (!mounted) return;

      if (res.statusCode == 404) {
        setState(() {
          _saved = null;
          _editing = true;
          _loading = false;
        });
        return;
      }

      if (res.statusCode != 200) {
        setState(() {
          _loadError = 'Failed to load (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final details = EntityDetails.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      setState(() {
        _saved = details;
        _editing = false;
        _nameController.text = details.name;
        _abnController.text = details.abn;
        _incorporationController.text = details.incorporationIdentifier;
        _apcaIdController.text = details.apcaId ?? '';
        _moneyInReceiptFormatController.text = details.moneyInReceiptFormat;
        _moneyOutReceiptFormatController.text = details.moneyOutReceiptFormat;
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

  Future<void> _save() async {
    if (!_isCreating) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update entity details?'),
          content: const Text(
            'Changing entity details will affect all records in the system. '
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      final body = jsonEncode({
        'name': _nameController.text.trim(),
        'abn': _abnController.text.trim(),
        'incorporationIdentifier': _incorporationController.text.trim(),
        'apcaId': _apcaIdController.text.trim(),
        'moneyInReceiptFormat': _moneyInReceiptFormatController.text.trim(),
        'moneyOutReceiptFormat': _moneyOutReceiptFormatController.text.trim(),
      });

      final res =
          await context.read<ApiClient>().put('/entity-details', body);
      if (!mounted) return;

      if (res.statusCode == 200) {
        final details = EntityDetails.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() {
          _saved = details;
          _editing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entity details saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String msg = 'Save failed (${res.statusCode})';
        try {
          msg = (jsonDecode(res.body) as Map)['error'] as String? ?? msg;
        } catch (_) {}
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startEdit() {
    setState(() {
      _nameController.text = _saved!.name;
      _abnController.text = _saved!.abn;
      _incorporationController.text = _saved!.incorporationIdentifier;
      _apcaIdController.text = _saved!.apcaId ?? '';
      _moneyInReceiptFormatController.text = _saved!.moneyInReceiptFormat;
      _moneyOutReceiptFormatController.text = _saved!.moneyOutReceiptFormat;
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _nameController.text = _saved!.name;
      _abnController.text = _saved!.abn;
      _incorporationController.text = _saved!.incorporationIdentifier;
      _apcaIdController.text = _saved!.apcaId ?? '';
      _moneyInReceiptFormatController.text = _saved!.moneyInReceiptFormat;
      _moneyOutReceiptFormatController.text = _saved!.moneyOutReceiptFormat;
      _editing = false;
    });
  }

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
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final canEdit = context.watch<AuthState>().canEdit;
    return Row(
      children: [
        Text('Entity Details',
            style: Theme.of(context).textTheme.headlineMedium),
        const Spacer(),
        if (!_loading && _loadError == null) ...[
          if (canEdit && !_editing && !_isCreating)
            FilledButton.icon(
              onPressed: _startEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          if (canEdit && _editing && !_isCreating) ...[
            OutlinedButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update'),
            ),
          ],
          if (canEdit && _isCreating)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isCreating)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'No entity details have been configured yet. '
                'Please enter your organisation information below.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          _buildField(
            label: 'Organisation Name',
            controller: _nameController,
            enabled: _editing,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'ABN',
            controller: _abnController,
            enabled: _editing,
            isRequired: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            helperText: '11 digits, no spaces',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Incorporation Identifier',
            controller: _incorporationController,
            enabled: _editing,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'APCA ID (User ID)',
            controller: _apcaIdController,
            enabled: _editing,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            helperText: '6-digit User ID assigned by your bank for Direct Entry',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          Text('Receipt Number Formats',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Tokens: # digit  @ letter  * alphanumeric  '
            'YY 2-digit year  YYYY 4-digit year  x? optional literal.\n'
            'All other characters are required literals. '
            'Leave blank for no constraint.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Money-In Receipt Format',
            controller: _moneyInReceiptFormatController,
            enabled: _editing,
            helperText: 'e.g. #######',
          ),
          _buildFormatExample(_moneyInReceiptFormatController.text),
          const SizedBox(height: 16),
          _buildField(
            label: 'Money-Out Receipt Format',
            controller: _moneyOutReceiptFormatController,
            enabled: _editing,
            helperText: 'e.g. P-?YY###',
          ),
          _buildFormatExample(_moneyOutReceiptFormatController.text),
        ],
      ),
    );
  }

  Widget _buildFormatExample(String pattern) {
    final fmt = ReceiptFormat(pattern);
    if (fmt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        'Example: ${fmt.example()}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.black45),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    final isEmpty = isRequired && controller.text.trim().isEmpty;
    return TextFormField(
      controller: controller,
      enabled: enabled && !_saving,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: isEmpty ? '$label (!)' : label,
        labelStyle: isEmpty ? const TextStyle(color: Colors.red) : null,
        helperText: helperText,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade50,
      ),
    );
  }
}
