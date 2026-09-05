import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/add_customer_dialog.dart';
import '../widgets/design_system.dart';
import '../widgets/price_text.dart';
import '../models/sales_trend.dart';
import '../theme/app_theme.dart';

class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  String _query = '';
  String _filter = 'All';

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
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => AddCustomerDialog(store: widget.store),
    );
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
      builder: (context, _) {
        final now = DateTime.now();
        final weekStart = reportStart(ReportPeriod.week, now);
        final pending = widget.store.customers
            .where((customer) => customer.balance > 0)
            .length;
        final collected = widget.store.customers
            .expand((customer) => customer.ledger)
            .where(
              (entry) =>
                  entry.type == LedgerEntryType.payment &&
                  !entry.createdAt.isBefore(weekStart) &&
                  !entry.createdAt.isAfter(now),
            )
            .fold<double>(0, (total, entry) => total + entry.amount);
        final customers = _customers
            .where(
              (customer) =>
                  _filter == 'All' ||
                  (_filter == 'Pending'
                      ? customer.balance > 0
                      : customer.balance <= 0),
            )
            .toList();
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                MetricHero(
                  label: 'Total outstanding balance',
                  amount: money(widget.store.totalOutstanding),
                  icon: Icons.menu_book_outlined,
                  footer: Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      Text('$pending active debts'),
                      Text('${money(collected)} collected this week'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search customer name or phone...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Pending', 'Paid']
                      .map(
                        (filter) => ChoiceChip(
                          label: Text(
                            filter == 'All'
                                ? 'All (${widget.store.customers.length})'
                                : filter,
                          ),
                          selected: _filter == filter,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: _filter == filter
                                ? Colors.white
                                : AppTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                const SectionHeading(
                  'Customer records',
                  subtitle: 'Highest balance first',
                ),
                const SizedBox(height: 12),
                if (customers.isEmpty)
                  const EmptyState(
                    title: 'No customers found.',
                    message: 'Add a customer or choose another filter.',
                    icon: Icons.people_outline,
                  ),
                ...customers.map(
                  (customer) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerLedgerScreen(
                              store: widget.store,
                              customer: customer,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: customer.balance > 0
                                      ? const Color(0xFFFFFBEB)
                                      : AppTheme.mint,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  customer.name.trim().isEmpty
                                      ? '?'
                                      : customer.name
                                            .trim()
                                            .split(RegExp(r'\s+'))
                                            .take(2)
                                            .map(
                                              (word) => word.characters.first,
                                            )
                                            .join()
                                            .toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: customer.balance > 0
                                        ? const Color(0xFFB45309)
                                        : AppTheme.emerald,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      customer.phone.isNotEmpty
                                          ? customer.phone
                                          : '${customer.ledger.length} ledger entries',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    PriceText(
                                      money(customer.balance),
                                      style: const TextStyle(
                                        fontFamily: 'SpaceGrotesk',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    StatusPill(
                                      customer.balance > 0 ? 'Pending' : 'Paid',
                                      color: customer.balance > 0
                                          ? const Color(0xFFB45309)
                                          : AppTheme.emerald,
                                      background: customer.balance > 0
                                          ? const Color(0xFFFFFBEB)
                                          : AppTheme.mint,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        );
      },
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
    final route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
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
    await Navigator.of(context).push(route);
    await route.completed;
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
            MetricHero(
              label: 'Customer balance',
              amount: money(customer.balance),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (customer.phone.isNotEmpty) ...[
                    Text(customer.phone),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.emerald,
                    ),
                    onPressed: customer.balance > 0
                        ? () => _recordPayment(context)
                        : null,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Pay Utang'),
                  ),
                ],
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
