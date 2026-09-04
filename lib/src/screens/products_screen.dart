import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';
import 'barcode_scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _products {
    final query = _query.toLowerCase();
    return widget.store.products.where((product) {
      if (!_showArchived && product.isArchived) return false;
      return query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.barcode.contains(query);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _editProduct([Product? product]) async {
    await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDialog(store: widget.store, product: product),
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
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search products, categories, or barcodes',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show archived products'),
                value: _showArchived,
                onChanged: (value) => setState(() => _showArchived = value),
              ),
              Row(
                children: [
                  Expanded(
                    child: _InventorySummary(
                      label: 'Active products',
                      value: '${widget.store.activeProducts.length}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InventorySummary(
                      label: 'Low stock',
                      value:
                          '${widget.store.activeProducts.where((p) => p.isLowStock).length}',
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_products.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: Text('No products found.')),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _InventoryCard(
                      product: product,
                      onEdit: () => _editProduct(product),
                      onArchive: () => widget.store.toggleArchive(product),
                    );
                  },
                ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'addProduct',
              onPressed: _editProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.product,
    required this.onEdit,
    required this.onArchive,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = product.stock == 0 || product.isArchived
        ? colors.error
        : product.isLowStock
        ? const Color(0xFFBA1A1A)
        : colors.primary;
    final statusBackground = product.stock == 0 || product.isArchived
        ? colors.errorContainer
        : product.isLowStock
        ? const Color(0xFFFFDAD6)
        : const Color(0xFFE0F3E2);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 142,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ProductImage(imagePath: product.imagePath),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      product.isArchived
                          ? 'ARCHIVED'
                          : product.stock == 0
                          ? 'OUT OF STOCK'
                          : product.isLowStock
                          ? 'LOW: ${product.stock}'
                          : 'IN STOCK: ${product.stock}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'archive') onArchive();
                    },
                    itemBuilder: (_) => [
                      if (!product.isArchived)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit product'),
                        ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          product.isArchived
                              ? 'Restore product'
                              : 'Archive product',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      decoration: product.isArchived
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          money(product.price),
                          style: TextStyle(
                            color: colors.primaryContainer,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Edit product',
                        onPressed: product.isArchived ? null : onEdit,
                        icon: const Icon(Icons.edit_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({
    super.key,
    required this.store,
    this.product,
    this.initialBarcode = '',
  });

  final AppStore store;
  final Product? product;
  final String initialBarcode;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _barcode;
  late final TextEditingController _threshold;
  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _cost = TextEditingController(
      text: product?.costPrice?.toStringAsFixed(2) ?? '',
    );
    _price = TextEditingController(
      text: product?.price.toStringAsFixed(2) ?? '',
    );
    _stock = TextEditingController(text: '${product?.stock ?? 0}');
    _barcode = TextEditingController(
      text: product?.barcode ?? widget.initialBarcode,
    );
    _threshold = TextEditingController(
      text: '${product?.lowStockThreshold ?? 5}',
    );
    _imagePath = product?.imagePath;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _cost.dispose();
    _price.dispose();
    _stock.dispose();
    _barcode.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    String? storedImagePath;
    try {
      storedImagePath = await widget.store.importProductImage(
        _imagePath,
        previousPath: widget.product?.imagePath,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the product photo: $error')),
      );
      return;
    }
    if (!mounted) return;
    final savedProduct = widget.store.saveProduct(
      existing: widget.product,
      name: _name.text,
      category: _category.text,
      costPrice: double.parse(_cost.text),
      price: double.parse(_price.text),
      stock: int.parse(_stock.text),
      imagePath: storedImagePath,
      barcode: _barcode.text,
      lowStockThreshold: int.parse(_threshold.text),
    );
    Navigator.pop(context, savedProduct);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;
    final photo = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 86,
    );
    if (photo != null && mounted) setState(() => _imagePath = photo.path);
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );
    if (barcode != null && barcode.isNotEmpty) {
      _barcode.text = barcode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isNew = widget.product == null;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(isNew ? 'Add New Product' : 'Edit Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              isNew
                  ? 'Enter details for the new inventory item.'
                  : 'Update this inventory item.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            const Text(
              'PRODUCT IMAGE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickPhoto,
              child: Container(
                height: 160,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _imagePath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFF4F8F3),
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Upload Product Photo'),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ProductImage(imagePath: _imagePath),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconButton.filledTonal(
                              tooltip: 'Remove photo',
                              onPressed: () =>
                                  setState(() => _imagePath = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                hintText: 'e.g., Bear Brand Fortified 320g',
              ),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _category,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'e.g., Drinks, Snacks, Canned Goods',
              ),
              validator: _required,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      prefixText: '₱ ',
                    ),
                    validator: _money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Selling Price',
                      prefixText: '₱ ',
                    ),
                    validator: _money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Current Stock',
                    ),
                    validator: _wholeNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Min Stock Alert',
                    ),
                    validator: _wholeNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Barcode (optional)',
                prefixIcon: const Icon(Icons.qr_code_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Scan barcode with camera',
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ),
              validator: (value) {
                final barcode = value?.trim() ?? '';
                if (barcode.isEmpty) return null;
                final duplicate = widget.store.products.any(
                  (product) =>
                      !identical(product, widget.product) &&
                      !product.isArchived &&
                      product.barcode == barcode,
                );
                return duplicate
                    ? 'Another active product already uses this barcode.'
                    : null;
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: colors.surface,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'SAVING...' : 'SAVE PRODUCT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _money(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter a valid amount.' : null;
  }

  String? _wholeNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter 0 or more.' : null;
  }
}
