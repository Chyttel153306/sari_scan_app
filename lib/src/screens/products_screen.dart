import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../store/app_store.dart';
import '../widgets/product_image.dart';
import '../widgets/catalog_product_card.dart';
import '../widgets/design_system.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid.dart';
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
  String _category = 'All';
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
      if (_category != 'All' && product.category != _category) return false;
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

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Delete ${product.name} from inventory and the cart? '
          'Past sales and utang records will be kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete product'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.store.deleteProduct(product);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} deleted.')));
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
                  hintText: 'Search products...',
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      {
                            'All',
                            ...widget.store.products.map(
                              (product) => product.category,
                            ),
                          }
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  category == 'All' ? 'All Items' : category,
                                ),
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
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_products.length} products',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                  const Flexible(
                    child: Text(
                      'Show archived',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Switch(
                    value: _showArchived,
                    onChanged: (value) => setState(() => _showArchived = value),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_products.isEmpty)
                const EmptyState(
                  title: 'No products found.',
                  message: 'Add a product or try a different search.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: productGridDelegate(
                      context,
                      availableWidth: constraints.maxWidth,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return CatalogProductCard(
                        inventory: true,
                        product: product,
                        onEdit: () => _editProduct(product),
                        onArchive: () => widget.store.toggleArchive(product),
                        onDelete: () => _deleteProduct(product),
                      );
                    },
                  ),
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
