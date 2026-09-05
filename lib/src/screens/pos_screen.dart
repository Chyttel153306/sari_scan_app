import 'package:flutter/material.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/catalog_product_card.dart';
import '../widgets/design_system.dart';
import '../theme/app_theme.dart';
import '../widgets/price_text.dart';
import '../widgets/product_grid.dart';
import 'barcode_scanner_screen.dart';
import 'checkout_screen.dart';
import 'products_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _visibleProducts {
    final query = _query.toLowerCase();
    return widget.store.activeProducts.where((product) {
      final matchesCategory =
          _category == 'All' || product.category == _category;
      final matchesSearch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.barcode.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _openBarcodeEntry() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    final product = widget.store.findByBarcode(barcode);
    if (product == null) {
      final addProduct = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Barcode not found'),
          content: Text(
            'No product uses barcode $barcode. Would you like to add it to inventory?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add product'),
            ),
          ],
        ),
      );
      if (!mounted || addProduct != true) return;
      final savedProduct = await Navigator.push<Product>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProductDialog(store: widget.store, initialBarcode: barcode),
        ),
      );
      if (!mounted || savedProduct == null) return;
      widget.store.addToCart(savedProduct);
      return;
    }
    widget.store.addToCart(product);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} added to cart.')));
  }

  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => _CartSheet(
            store: widget.store,
            onCheckout: () {
              Navigator.pop(context);
              Navigator.push(
                this.context,
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(store: widget.store),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      'All',
      ...widget.store.activeProducts.map((product) => product.category),
    }.toList();

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Search product...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        tooltip: 'Scan barcode',
                        onPressed: _openBarcodeEntry,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(56, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return ChoiceChip(
                        label: Text(category == 'All' ? 'All Items' : category),
                        labelStyle: TextStyle(
                          color: _category == category
                              ? Colors.white
                              : AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        selected: _category == category,
                        selectedColor: AppTheme.emerald,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    '${_visibleProducts.length} products available',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ),
              ),
              if (_visibleProducts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      title: 'No matching products found.',
                      message: 'Add products in inventory to start selling.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid.builder(
                      gridDelegate: productGridDelegate(
                        context,
                        availableWidth: constraints.crossAxisExtent,
                      ),
                      itemCount: _visibleProducts.length,
                      itemBuilder: (context, index) {
                        final product = _visibleProducts[index];
                        return CatalogProductCard(
                          product: product,
                          onAdd: product.stock > 0
                              ? () => widget.store.addToCart(product)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          if (widget.store.cartItemCount > 0)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.ink,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _openCart,
                        tooltip: 'View cart',
                        icon: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: _openCart,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.store.cartItemCount} Items in Cart',
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 10,
                                ),
                              ),
                              PriceText(
                                money(widget.store.cartTotal),
                                style: const TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheckoutScreen(store: widget.store),
                          ),
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Charge'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  const _CartSheet({required this.store, required this.onCheckout});

  final AppStore store;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Current cart',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text('${store.cartItemCount} item(s)'),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: store.cartLines.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final line = store.cartLines[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.product.name),
                  subtitle: Text(
                    '${money(line.product.price)} × ${line.quantity} = ${money(line.subtotal)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => store.removeOneFromCart(line.product),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${line.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: line.quantity < line.product.stock
                            ? () => store.addToCart(line.product)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: PriceText(
                  money(store.cartTotal),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: store.cartLines.isEmpty ? null : onCheckout,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Proceed to checkout'),
          ),
        ],
      ),
    );
  }
}
