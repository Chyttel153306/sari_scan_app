import 'package:flutter/material.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import 'receipt_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.today;

  String _label(ReportPeriod period) {
    return switch (period) {
      ReportPeriod.today => 'Today',
      ReportPeriod.week => 'Week',
      ReportPeriod.month => 'Month',
      ReportPeriod.year => 'Year',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final sales = widget.store.salesFor(_period);
        final total = sales.fold<double>(0, (sum, sale) => sum + sale.total);
        final cash = sales
            .where((sale) => sale.paymentType == PaymentType.cash)
            .fold<double>(0, (sum, sale) => sum + sale.total);
        final utang = total - cash;
        final hasUnknownCosts = sales.any(
          (sale) => sale.items.any((item) => item.unitCost == null),
        );
        final netProfit = sales.isEmpty || hasUnknownCosts
            ? null
            : sales.fold<double>(
                0,
                (sum, sale) =>
                    sum +
                    sale.items.fold<double>(
                      0,
                      (itemSum, item) =>
                          itemSum +
                          (item.unitPrice - item.unitCost!) * item.quantity,
                    ),
              );
        final trend = _buildTrend(_period, sales);
        final quantityByProduct = <String, int>{};
        for (final sale in sales) {
          for (final item in sale.items) {
            quantityByProduct.update(
              item.productName,
              (quantity) => quantity + item.quantity,
              ifAbsent: () => item.quantity,
            );
          }
        }
        final topProducts = quantityByProduct.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Reports',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ReportPeriod.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final period = ReportPeriod.values[index];
                  return ChoiceChip(
                    label: Text(_label(period)),
                    selected: _period == period,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onSelected: (_) => setState(() => _period = period),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Sales',
                      style: TextStyle(color: Color(0xFFCBFFC2), fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(color: Color(0x5588D982)),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          color: Color(0xFFCBFFC2),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Transactions',
                          style: TextStyle(
                            color: Color(0xFFCBFFC2),
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${sales.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Profit',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            netProfit == null ? '—' : money(netProfit),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        sales.isEmpty
                            ? 'No sales yet'
                            : hasUnknownCosts
                            ? 'Cost price is unavailable for older sales'
                            : 'Based on saved cost prices',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Trend',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    if (sales.isEmpty)
                      const SizedBox(
                        height: 118,
                        child: Center(
                          child: Text(
                            'Complete a sale to see the sales trend.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      _SalesTrendChart(points: trend),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Top products',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: topProducts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Complete a sale to see product rankings.'),
                      ),
                    )
                  : Column(
                      children: topProducts
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (ranked) => ListTile(
                              leading: CircleAvatar(
                                child: Text('${ranked.key + 1}'),
                              ),
                              title: Text(ranked.value.key),
                              trailing: Text(
                                '${ranked.value.value} sold',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Methods',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    _PaymentBar(
                      label: 'Cash',
                      value: cash,
                      total: total,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    _PaymentBar(
                      label: 'Utang',
                      value: utang,
                      total: total,
                      color: const Color(0xFF8C6800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction history',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('${sales.length} record(s)'),
              ],
            ),
            const SizedBox(height: 8),
            if (sales.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text('No completed sales in this period.'),
                  ),
                ),
              )
            else
              ...sales.map(
                (sale) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          sale.paymentType == PaymentType.cash
                              ? Icons.payments_outlined
                              : Icons.menu_book_outlined,
                        ),
                      ),
                      title: Text(
                        receiptNumber(sale.id),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${shortDateTime(sale.createdAt)}\n'
                        '${sale.items.length} product line(s) • ${sale.paymentType == PaymentType.cash ? 'Cash' : 'Utang'}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        money(sale.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiptScreen(sale: sale),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaymentBar extends StatelessWidget {
  const _PaymentBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              money(value),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            color: color,
            backgroundColor: const Color(0xFFE5E2E1),
          ),
        ),
      ],
    );
  }
}

class _TrendPoint {
  const _TrendPoint(this.label, this.value);

  final String label;
  final double value;
}

List<_TrendPoint> _buildTrend(ReportPeriod period, List<SaleRecord> sales) {
  late final List<String> labels;
  late final int Function(DateTime) bucketFor;
  switch (period) {
    case ReportPeriod.today:
      labels = const ['12am', '4am', '8am', '12pm', '4pm', '8pm'];
      bucketFor = (date) => date.hour ~/ 4;
    case ReportPeriod.week:
      labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      bucketFor = (date) => date.weekday - 1;
    case ReportPeriod.month:
      labels = const ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];
      bucketFor = (date) => ((date.day - 1) ~/ 7).clamp(0, 4);
    case ReportPeriod.year:
      labels = const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      bucketFor = (date) => date.month - 1;
  }
  final totals = List<double>.filled(labels.length, 0);
  for (final sale in sales) {
    final bucket = bucketFor(sale.createdAt);
    totals[bucket] += sale.total;
  }
  return List.generate(
    labels.length,
    (index) => _TrendPoint(labels[index], totals[index]),
  );
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (maximum, point) => point.value > maximum ? point.value : maximum,
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final fraction = maxValue == 0 ? 0.0 : point.value / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: '${point.label}: ${money(point.value)}',
                    child: Container(
                      height: point.value == 0 ? 2 : 92 * fraction + 10,
                      decoration: BoxDecoration(
                        color: point.value == maxValue
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFDDF5DC),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      point.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
