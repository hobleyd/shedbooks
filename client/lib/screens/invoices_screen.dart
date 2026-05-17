import 'package:flutter/material.dart';
import '../widgets/contact_picker.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final ContactPickerController _contactController =
      ContactPickerController(onlyCompanies: true);

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoices', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ContactPicker(controller: _contactController),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  Text(
                    'Invoice Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Invoice line items and totals will be added here.'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
