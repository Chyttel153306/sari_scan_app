import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/sales_trend.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/price_text.dart';
import '../widgets/sales_trend_chart.dart';
import '../widgets/design_system.dart';
import '../theme/app_theme.dart';
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
        final now = DateTime.now();
        final sales = widget.store.salesFor(_period, now: now);
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
        final trend = buildSalesTrend(_period, sales, now: now);
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
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: ReportPeriod.values
                    .map(
                      (period) => Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _period = period),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _period == period
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _label(period),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _period == period
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: _period == period
                                    ? const Color(0xFF065F46)
                                    : AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            MetricHero(
              label: 'Total sales',
              amount: money(total),
              icon: Icons.trending_up,
              footer: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transactions'),
                        const SizedBox(height: 4),
                        Text(
                          '${sales.length} orders',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Average basket'),
                        const SizedBox(height: 4),
                        PriceText(
                          money(sales.isEmpty ? 0 : total / sales.length),
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                          PriceText(
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Trend',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${shortDateTime(reportStart(_period, now)).split(' ').first} to '
                      '${shortDateTime(now).split(' ').first}',
                      style: Theme.of(context).textTheme.bodySmall,
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
                      SalesTrendChart(key: ValueKey(_period), points: trend),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment breakdown',
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
                Expanded(
                  child: Text(
                    'Transaction history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${shortDateTime(sale.createdAt)}\n'
                        '${sale.items.length} product line(s) • ${sale.paymentType == PaymentType.cash ? 'Cash' : 'Utang'}',
                      ),
                      isThreeLine: true,
                      trailing: SizedBox(
                        width: 90,
                        child: PriceText(
                          money(sale.total),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
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
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: PriceText(
                money(value),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
