import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/add_customer_dialog.dart';
import '../widgets/price_text.dart';
import '../widgets/design_system.dart';
import '../theme/app_theme.dart';
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
        customer: _paymentType == PaymentType.utang ? _customer : null,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
      );
    } on StateError catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  Future<void> _addCustomer() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => AddCustomerDialog(store: widget.store),
    );
    if (!mounted || customer == null) return;
    setState(() {
      _customer = customer;
      _error = null;
    });
  }

  void _selectPayment(PaymentType type) => setState(() {
    _paymentType = type;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final total = widget.store.cartTotal;
    final change = _cash - total;
    final canComplete =
        widget.store.cartItemCount > 0 &&
        (_paymentType == PaymentType.cash ? _cash >= total : _customer != null);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: FilledButton.icon(
              onPressed: canComplete ? _complete : null,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text('Complete sale'),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeading(
                        'Order summary',
                        trailing: StatusPill(
                          '${widget.store.cartItemCount} items',
                          color: AppTheme.muted,
                          background: AppTheme.canvas,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...widget.store.cartLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.canvas,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  '${line.quantity}',
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  line.product.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: PriceText(
                                    money(line.subtotal),
                                    style: const TextStyle(
                                      fontFamily: 'SpaceGrotesk',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.mint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'TOTAL AMOUNT TO PAY',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: .8,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            PriceText(
                              money(total),
                              style: const TextStyle(
                                fontFamily: 'SpaceGrotesk',
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeading(
                'Payment method',
                subtitle: 'Choose how this order will be paid',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      label: 'Cash',
                      subtitle: 'Immediate payment',
                      icon: Icons.payments_outlined,
                      selected: _paymentType == PaymentType.cash,
                      onTap: () => _selectPayment(PaymentType.cash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      label: 'Utang',
                      subtitle: 'Store credit',
                      icon: Icons.menu_book_outlined,
                      selected: _paymentType == PaymentType.utang,
                      onTap: () => _selectPayment(PaymentType.utang),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_paymentType == PaymentType.cash)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _cashController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () =>
                              FocusScope.of(context).unfocus(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cash received',
                            prefixText: '₱ ',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          onChanged: (_) => setState(() => _error = null),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ActionChip(
                              label: const Text('Exact'),
                              onPressed: () => setState(
                                () => _cashController.text = total
                                    .toStringAsFixed(2),
                              ),
                            ),
                            ...[100.0, 500.0, 1000.0]
                                .where((value) => value > total)
                                .map(
                                  (value) => ActionChip(
                                    label: Text(money(value)),
                                    onPressed: () => setState(
                                      () => _cashController.text = value
                                          .toStringAsFixed(2),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                change >= 0 ? 'Change' : 'Amount still due',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: PriceText(
                                money(change.abs()),
                                style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: change >= 0
                                      ? AppTheme.emerald
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          'Select customer for utang',
                          subtitle: 'The full amount goes to their ledger',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Customer>(
                          key: ValueKey(_customer?.id),
                          initialValue: _customer,
                          isExpanded: true,
                          hint: Text(
                            widget.store.customers.isEmpty
                                ? 'Add your first customer below'
                                : 'Select a customer',
                          ),
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
                                    style: const TextStyle(fontSize: 12),
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
                        TextButton.icon(
                          onPressed: _addCustomer,
                          icon: const Icon(Icons.person_add_alt_1, size: 20),
                          label: const Text('Add customer'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppTheme.mint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppTheme.emerald : AppTheme.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? AppTheme.emerald : AppTheme.muted,
                    size: 24,
                  ),
                  const Spacer(),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? AppTheme.emerald : AppTheme.border,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
