import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cashController = TextEditingController();
  PaymentType _paymentType = PaymentType.cash;
  Customer? _customer;
  String? _error;

  double get _cash => double.tryParse(_cashController.text) ?? 0;

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _complete() {
    setState(() => _error = null);
    try {
      final sale = widget.store.completeSale(
        paymentType: _paymentType,
        amountReceived: _cash,
        customer: _customer,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
      );
    } on StateError catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.store.cartTotal;
    final change = _cash - total;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Order summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.store.cartLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line.quantity} × ${line.product.name}',
                            ),
                          ),
                          Text(money(line.subtotal)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount due',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        money(total),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<PaymentType>(
            segments: const [
              ButtonSegment(
                value: PaymentType.cash,
                icon: Icon(Icons.payments_outlined),
                label: Text('Cash'),
              ),
              ButtonSegment(
                value: PaymentType.utang,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Utang'),
              ),
            ],
            selected: {_paymentType},
            onSelectionChanged: (values) => setState(() {
              _paymentType = values.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_paymentType == PaymentType.cash) ...[
            TextField(
              controller: _cashController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Cash received',
                prefixText: '₱ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            Card(
              color: change >= 0
                  ? const Color(0xFFDDF5DC)
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(change >= 0 ? 'Change' : 'Amount still due'),
                    Text(
                      money(change.abs()),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            DropdownButtonFormField<Customer>(
              initialValue: _customer,
              decoration: const InputDecoration(
                labelText: 'Customer',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: widget.store.customers
                  .map(
                    (customer) => DropdownMenuItem(
                      value: customer,
                      child: Text(
                        '${customer.name} • ${money(customer.balance)} balance',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _customer = value;
                _error = null;
              }),
            ),
            const SizedBox(height: 10),
            const Text(
              'The full sale amount will be added to the selected customer’s ledger.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _paymentType == PaymentType.cash
                ? (_cash >= total ? _complete : null)
                : (_customer != null ? _complete : null),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete sale'),
          ),
        ],
      ),
    );
  }
}
