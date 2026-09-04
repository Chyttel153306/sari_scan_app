import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';

class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  String _query = '';

  List<Customer> get _customers {
    final query = _query.toLowerCase();
    return widget.store.customers
        .where(
          (customer) =>
              query.isEmpty ||
              customer.name.toLowerCase().contains(query) ||
              customer.phone.contains(query),
        )
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
  }

  Future<void> _addCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Customer name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                widget.store.addCustomer(name.text, phone.text),
              );
            },
            child: const Text('Add customer'),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    if (!mounted || customer == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerLedgerScreen(store: widget.store, customer: customer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Utang List',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Total Outstanding: ${money(widget.store.totalOutstanding)}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFD6),
                      border: Border.all(color: const Color(0xFFFABD00)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${widget.store.customers.where((c) => c.balance > 0).length} Pending',
                      style: const TextStyle(
                        color: Color(0xFF8C6800),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search customer name...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 14),
              if (_customers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 42),
                  child: Center(child: Text('No customers found.')),
                )
              else
                ..._customers.map(
                  (customer) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEAE7E7),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            customer.name.isEmpty
                                ? '?'
                                : customer.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          customer.phone.isEmpty
                              ? '${customer.ledger.length} ledger entries'
                              : customer.phone,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(customer.balance),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: customer.balance > 0
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (customer.balance > 0)
                              Text(
                                'Pending',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerLedgerScreen(
                              store: widget.store,
                              customer: customer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'addCustomer',
              onPressed: _addCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add customer'),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerLedgerScreen extends StatelessWidget {
  const CustomerLedgerScreen({
    super.key,
    required this.store,
    required this.customer,
  });

  final AppStore store;
  final Customer customer;

  Future<void> _recordPayment(BuildContext context) async {
    final controller = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Record payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Outstanding: ${money(customer.balance)}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Payment amount',
                  prefixText: '₱ ',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(controller.text) ?? 0;
                final result = store.recordPayment(customer, amount);
                if (result == null) {
                  Navigator.pop(dialogContext);
                } else {
                  setState(() => error = result);
                }
              },
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(customer.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL BALANCE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      money(customer.balance),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (customer.phone.isNotEmpty) Text(customer.phone),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: customer.balance > 0
                          ? () => _recordPayment(context)
                          : null,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pay Utang'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Transaction History',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (customer.ledger.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No credit purchases or payments yet.'),
                ),
              )
            else
              ...customer.ledger.map(
                (entry) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        entry.type == LedgerEntryType.credit
                            ? Icons.add_rounded
                            : Icons.remove_rounded,
                      ),
                    ),
                    title: Text(entry.note),
                    subtitle: Text(shortDateTime(entry.createdAt)),
                    trailing: Text(
                      '${entry.type == LedgerEntryType.credit ? '+' : '-'}${money(entry.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: entry.type == LedgerEntryType.credit
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
