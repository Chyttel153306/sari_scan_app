import 'package:flutter/material.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';
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
                        selected: _category == category,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
              ),
              if (_visibleProducts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No matching products found.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 226,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _visibleProducts.length,
                    itemBuilder: (context, index) {
                      final product = _visibleProducts[index];
                      return _ProductCard(
                        product: product,
                        onAdd: product.stock > 0
                            ? () => widget.store.addToCart(product)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
          if (widget.store.cartItemCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 10,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.24),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _openCart,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.store.cartItemCount} Items in Cart',
                                    style: const TextStyle(
                                      color: Color(0xFFCBFFC2),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    money(widget.store.cartTotal),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              minimumSize: const Size(138, 48),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CheckoutScreen(store: widget.store),
                              ),
                            ),
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text(
                              'Charge',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
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
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final Product product;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ProductImage(imagePath: product.imagePath),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: product.stock == 0
                            ? colors.errorContainer
                            : product.isLowStock
                            ? const Color(0xFFFFEFD6)
                            : const Color(0xFFE0F3E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.stock == 0
                            ? 'OUT OF STOCK'
                            : product.isLowStock
                            ? '${product.stock} LEFT'
                            : '${product.stock} IN STOCK',
                        style: TextStyle(
                          color: product.stock == 0
                              ? colors.error
                              : product.isLowStock
                              ? colors.tertiary
                              : colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            money(product.price),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: onAdd == null
                                      ? colors.outline
                                      : colors.primaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: onAdd == null
                                ? colors.surfaceContainerHighest
                                : colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: onAdd == null
                                ? colors.outline
                                : Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              Text('Total', style: Theme.of(context).textTheme.titleLarge),
              Text(
                money(store.cartTotal),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
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
