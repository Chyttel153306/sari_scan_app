import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.firstUse = false});

  final bool firstUse;
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _index = 0;
  final _scroll = ScrollController();
  static const _topics = [
    (
      'Products',
      Icons.inventory_2_outlined,
      'Add your first product',
      'Save what you sell, its price, and how many you have.',
      'Products > +',
      [
        'Tap Products in the bottom menu, then the + button in the bottom corner.',
        'Enter Product Name and Category. Cost Price is what you pay; Selling Price is what the customer pays.',
        'Enter Initial Stock and Min Stock Alert to help you spot items that need restocking.',
        'Add a photo or barcode if you want, then tap SAVE PRODUCT.',
      ],
      'Example: Buy a snack for PHP 8, sell it for PHP 10, and enter 20 pieces as Initial Stock.',
      'Start with a few products. You can add more anytime.',
    ),
    (
      'POS',
      Icons.qr_code_scanner_rounded,
      'Build a customer order',
      'POS is your cash register. Add items here before taking payment.',
      'Bottom menu > POS',
      [
        'Tap a product card to add it to the cart. Tap it again for another piece.',
        'Use Search product or a category to find an item quickly.',
        'Tap the barcode icon beside search to scan. Allow camera access and point the camera at the barcode.',
        'Tap View cart to check items and use + or - to change quantities. Tap Charge to open checkout.',
      ],
      'Example: For two snacks, tap the snack twice and check that the cart shows 2.',
      'Scanning needs a saved product barcode. Choose Enter Manually if scanning is difficult. An unknown barcode lets you add a product.',
    ),
    (
      'Cash',
      Icons.payments_outlined,
      'Take a cash payment',
      'Check the total and let SariScan calculate the change.',
      'POS > Charge > Checkout',
      [
        'Review the items and total before accepting payment.',
        'Choose Cash and enter Cash received. Tap Exact if the customer pays the exact total.',
        'Check the change shown. Cash received must cover the total.',
        'After receiving payment, tap Complete sale. The sale is recorded and stock is reduced.',
      ],
      'Example: The total is PHP 35 and the customer gives PHP 50. Return PHP 15 in change.',
      'Only tap Complete sale when the order and payment are correct.',
    ),
    (
      'Receipts',
      Icons.receipt_long_outlined,
      'Give the customer a receipt',
      'Keep a sale record and share a copy with the customer.',
      'Complete sale > Transaction Complete',
      [
        'Review the receipt after completing the sale.',
        'Tap Print to choose an available printer or print service on your phone.',
        'Tap Send to share the receipt as a PDF using an app on your phone.',
        'Tap New Transaction when you are ready for the next customer.',
      ],
      'Need an old receipt? Open Reports and tap the sale in transaction history.',
      'Print and Send use the services available on your phone. You can finish a sale without printing.',
    ),
    (
      'Utang',
      Icons.menu_book_outlined,
      'Record credit and repayments',
      'Utang means the customer pays later. Track each customer balance here.',
      'Checkout > Utang / Bottom menu > Utang',
      [
        'For a credit sale, choose Utang at checkout instead of Cash.',
        'Select the customer or tap Add customer. Check the name before tapping Complete sale.',
        'When they repay, open the Utang tab and tap their name.',
        'Tap Pay Utang, enter the amount received, then tap Save payment. You can record part or all of the balance.',
      ],
      'Example: Ana owes PHP 100 and pays PHP 40. Save a PHP 40 payment; her remaining balance is PHP 60.',
      'Utang checkout adds the full order to the balance. Record repayments in Pay Utang, not as another sale.',
    ),
    (
      'Stock',
      Icons.add_box_outlined,
      'Keep stock up to date',
      'Record deliveries and update products as your store changes.',
      'Products > Product options (three dots)',
      [
        'Find the product in Products and open its three-dot Product options menu.',
        'Choose Add stock for a delivery. Enter Quantity received and an optional delivery note, then tap Add stock.',
        'Choose Edit product to update the name, price, photo, or other details.',
        'Choose Archive product to hide it from sales. Turn on Show archived and choose Restore product to bring it back.',
      ],
      'Example: You have 5 bottles and receive 12 more. Add stock: 12. Your new stock is 17.',
      'Delete product permanently removes it from inventory and the cart. Past sales and utang records stay saved.',
    ),
    (
      'Reports',
      Icons.bar_chart_outlined,
      'See how your store is doing',
      'Review sales totals, popular products, and past transactions.',
      'Bottom menu > Reports',
      [
        'Choose Today, Week, Month, or Year to see that period.',
        'Review Total sales, Transactions, and Average basket (the average amount per sale).',
        'Tap a chart bar to see its full amount. Swipe the chart sideways if more periods are off screen.',
        'Check product rankings and transaction history. Tap a transaction to open its receipt.',
      ],
      'Example: Use Today at closing time to review sales and the Cash and Utang totals.',
      'Total sales includes cash and utang purchases. Utang repayments do not count as new sales.',
    ),
    (
      'Settings',
      Icons.settings_outlined,
      'Make SariScan work for you',
      'Adjust preferences and share records between phones when needed.',
      'More > Settings',
      [
        'Use Store name or Appearance to personalize the app.',
        'Set Default markup to suggest selling prices from cost. You can still choose each product price.',
        'To use another phone, open Sync store and create a sync code on the phone holding your records. On the other phone, choose Join with a code.',
        'For later changes, use Upload changes on the source phone, then Download latest on the other phone. Sync needs internet and is manual.',
      ],
      'Example: A 10% markup on a PHP 100 cost suggests a PHP 110 selling price.',
      'Joining or downloading replaces records on the receiving phone. Upload changes you need first. Unlinking clears local records. Uninstalling or clearing app storage also removes local data.',
    ),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _index = index);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topics[_index];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final last = _index == _topics.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("SariScan tutorial")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.firstUse
                  ? context.tr("Skip tutorial")
                  : context.tr("Close"),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                context.tr("Your store, one step at a time"),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  "Follow in order, or tap a topic below. This guide only explains the app; it does not create products or sales.",
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _topics.length; i++)
                    ChoiceChip(
                      label: Text('${i + 1}. ${context.tr(_topics[i].$1)}'),
                      selected: i == _index,
                      onSelected: (_) => _goTo(i),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                header: true,
                child: Text(
                  context.tr(
                    "Step {0} of {1}: {2}",
                    args: [_index + 1, _topics.length, context.tr(topic.$3)],
                  ),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_index + 1) / _topics.length,
                semanticsLabel: context.tr("Tutorial progress"),
              ),
              const SizedBox(height: 20),
              Card(
                color: colors.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        topic.$2,
                        size: 36,
                        color: colors.onPrimaryContainer,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(topic.$4),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          "Where to go: {0}",
                          args: [context.tr(topic.$5)],
                        ),
                        style: TextStyle(color: colors.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < topic.$6.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                        child: Text('${i + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(topic.$6[i]),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(context.tr(topic.$7), style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                context.tr("Good to know"),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(context.tr(topic.$8)),
              const SizedBox(height: 20),
              Text(
                context.tr(
                  "Reopen this guide anytime from More > App tutorial.",
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(context.tr("Back")),
              ),
              FilledButton.icon(
                onPressed: last
                    ? () => Navigator.pop(context)
                    : () => _goTo(_index + 1),
                icon: Icon(
                  last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  last ? context.tr("Finish tutorial") : context.tr("Next"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
