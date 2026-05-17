import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';

import '../models/contact_entry.dart';
import '../services/api_client.dart';

enum AbnLookupState { idle, loading, found, notFound, error }

/// A controller for the [ContactPicker] widget.
class ContactPickerController extends ChangeNotifier {
  ContactEntry? _selectedContact;
  ContactEntry? get selectedContact => _selectedContact;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController abnController = TextEditingController();
  ContactType contactType = ContactType.person;
  bool gstRegistered = false;
  AbnLookupState abnLookupState = AbnLookupState.idle;

  bool _isNew = false;
  bool get isNew => _isNew;

  final bool onlyCompanies;

  ContactPickerController({this.onlyCompanies = false}) {
    if (onlyCompanies) {
      contactType = ContactType.company;
    }
  }

  void selectContact(ContactEntry? contact) {
    _selectedContact = contact;
    _isNew = false;
    if (contact != null) {
      nameController.text = contact.name;
      abnController.text = contact.abn ?? '';
      contactType = contact.contactType;
      gstRegistered = contact.gstRegistered;
    } else {
      clear();
    }
    notifyListeners();
  }

  void setToNew() {
    _selectedContact = null;
    _isNew = true;
    clear();
    if (onlyCompanies) {
      contactType = ContactType.company;
    }
    notifyListeners();
  }

  void clear() {
    nameController.clear();
    abnController.clear();
    contactType = onlyCompanies ? ContactType.company : ContactType.person;
    gstRegistered = false;
    abnLookupState = AbnLookupState.idle;
  }

  @override
  void dispose() {
    nameController.dispose();
    abnController.dispose();
    super.dispose();
  }
}

/// A widget that allows selecting a contact via typeahead or creating a new one.
class ContactPicker extends StatefulWidget {
  final ContactPickerController controller;
  final bool enabled;

  const ContactPicker({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  State<ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<ContactPicker> {
  Future<List<ContactEntry>> _searchContacts(String query) async {
    if (query.isEmpty) return [];
    try {
      final client = context.read<ApiClient>();
      // The backend doesn't have a search endpoint yet, so we fetch all and filter locally.
      // In a real app, this should be a server-side search.
      final res = await client.get('/contacts');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data
            .map((e) => ContactEntry.fromJson(e as Map<String, dynamic>))
            .where((c) {
              final matches =
                  c.name.toLowerCase().contains(query.toLowerCase());
              if (widget.controller.onlyCompanies) {
                return matches && c.contactType == ContactType.company;
              }
              return matches;
            })
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _lookupAbn() async {
    final abn = widget.controller.abnController.text.trim();
    if (!RegExp(r'^\d{11}$').hasMatch(abn)) return;

    setState(() => widget.controller.abnLookupState = AbnLookupState.loading);

    try {
      final res = await context.read<ApiClient>().get('/abn-lookup?abn=$abn');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final found = data['found'] as bool;
        if (!found) {
          setState(() => widget.controller.abnLookupState = AbnLookupState.notFound);
          return;
        }
        setState(() {
          widget.controller.gstRegistered = data['gstRegistered'] as bool;
          widget.controller.abnLookupState = AbnLookupState.found;
        });
      } else {
        setState(() => widget.controller.abnLookupState = AbnLookupState.error);
      }
    } catch (_) {
      if (mounted) {
        setState(() => widget.controller.abnLookupState = AbnLookupState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypeAheadField<ContactEntry>(
          builder: (context, textController, focusNode) => TextField(
            controller: textController,
            focusNode: focusNode,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Search Contact',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          onSelected: (contact) {
            controller.selectContact(contact);
          },
          suggestionsCallback: _searchContacts,
          itemBuilder: (context, contact) {
            return ListTile(
              title: Text(contact.name),
              subtitle: Text(contact.contactType == ContactType.company
                  ? 'Company - ${contact.abn}'
                  : 'Person'),
            );
          },
          emptyBuilder: (context) => ListTile(
            title: const Text('No contacts found'),
            trailing: TextButton(
              onPressed: () {
                controller.setToNew();
              },
              child: const Text('Create New'),
            ),
          ),
        ),
        if (controller.isNew || controller.selectedContact != null) ...[
          const SizedBox(height: 16),
          _buildContactForm(),
        ],
      ],
    );
  }

  Widget _buildContactForm() {
    final controller = widget.controller;
    final isNew = controller.isNew;
    final isCompany = controller.contactType == ContactType.company;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isNew ? 'New Contact' : 'Contact Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isNew)
                  TextButton(
                    onPressed: () => controller.selectContact(null),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller.nameController,
              enabled: widget.enabled && isNew,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!controller.onlyCompanies) ...[
                  Expanded(
                    child: DropdownButtonFormField<ContactType>(
                      initialValue: controller.contactType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ContactType.person,
                          child: Text('Person'),
                        ),
                        DropdownMenuItem(
                          value: ContactType.company,
                          child: Text('Company'),
                        ),
                      ],
                      onChanged: (widget.enabled && isNew)
                          ? (value) {
                              if (value == null) return;
                              setState(() {
                                controller.contactType = value;
                                if (value == ContactType.person) {
                                  controller.gstRegistered = false;
                                  controller.abnController.clear();
                                  controller.abnLookupState = AbnLookupState.idle;
                                }
                              });
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: _buildAbnField(),
                ),
              ],
            ),
            if (isCompany) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('GST Registered'),
                value: controller.gstRegistered,
                onChanged: (widget.enabled && isNew)
                    ? (value) {
                        setState(() => controller.gstRegistered = value ?? false);
                      }
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAbnField() {
    final controller = widget.controller;
    final isNew = controller.isNew;
    final isCompany = controller.contactType == ContactType.company;

    Widget? suffixIcon;
    switch (controller.abnLookupState) {
      case AbnLookupState.loading:
        suffixIcon = const Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case AbnLookupState.found:
        suffixIcon = const Icon(Icons.check_circle_outline,
            color: Colors.green, size: 18);
      case AbnLookupState.notFound:
        suffixIcon = Icon(Icons.cancel_outlined,
            color: Theme.of(context).colorScheme.error, size: 18);
      case AbnLookupState.error:
        suffixIcon = const Icon(Icons.warning_amber_outlined,
            color: Colors.orange, size: 18);
      case AbnLookupState.idle:
        suffixIcon = null;
    }

    return TextFormField(
      controller: controller.abnController,
      enabled: widget.enabled && isNew && isCompany,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      onChanged: (isNew && isCompany)
          ? (value) {
              setState(() => controller.abnLookupState = AbnLookupState.idle);
              if (value.length == 11) _lookupAbn();
            }
          : null,
      decoration: InputDecoration(
        labelText: 'ABN',
        border: const OutlineInputBorder(),
        hintText: isCompany ? '11 digits' : '—',
        suffixIcon: suffixIcon,
      ),
    );
  }
}
