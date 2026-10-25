import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../store/app_store.dart';

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key, required this.store});

  final AppStore store;

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted || !(_formKey.currentState?.validate() ?? false)) return;
    _submitted = true;
    final Customer customer = widget.store.addCustomer(_name.text, _phone.text);
    Navigator.pop(context, customer);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.tr("Add customer")),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: context.tr("Customer name")),
            validator: (value) => value == null || value.trim().isEmpty
                ? context.tr('Enter a customer name.')
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.tr("Phone (optional)"),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr("Cancel")),
      ),
      FilledButton(onPressed: _submit, child: Text(context.tr("Add customer"))),
    ],
  );
}
