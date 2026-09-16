import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

  Future<void> _addStock(Product product) async {
    final addition = await showDialog<StockAddition>(
      context: context,
      builder: (_) => AddStockDialog(store: widget.store, product: product),
    );
    if (!mounted || addition == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${addition.quantity} added to ${product.name}. Stock: ${product.stock}.',
        ),
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
                        onAddStock: () => _addStock(product),
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
            child: FloatingActionButton(
              heroTag: 'addProduct',
              onPressed: _editProduct,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class AddStockDialog extends StatefulWidget {
  const AddStockDialog({super.key, required this.store, required this.product});

  final AppStore store;
  final Product product;

  @override
  State<AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<AddStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _quantityValue => int.tryParse(_quantity.text) ?? 0;

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final addition = widget.store.addStock(
      product: widget.product,
      quantity: _quantityValue,
      note: _note.text,
    );
    Navigator.pop(context, addition);
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.store.stockAdditionsFor(widget.product);
    final afterStock = widget.product.stock + _quantityValue;
    return AlertDialog(
      title: const Text('Add stock'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.product.name),
              const SizedBox(height: 4),
              Text(
                'Current stock: ${widget.product.stock}  •  After adding: $afterStock',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _quantity,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantity received',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final quantity = int.tryParse(value ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Enter a quantity greater than zero.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery / invoice note',
                  hintText: 'e.g., Supplier invoice #1234',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add a delivery or invoice note for the audit trail.'
                    : null,
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'STOCK-IN HISTORY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final entry in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '+${entry.quantity} • ${_formatDateTime(entry.createdAt)}\n'
                      '${entry.note} • ${entry.addedBy}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Add stock'),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} ${local.hour}:$minute';
  }
}

class _PhotoSuggestion {
  const _PhotoSuggestion({this.name, this.category});

  final String? name;
  final String? category;
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

  // Category dropdown-in-textfield plumbing: a FocusNode so we know when the
  // field is active, a LayerLink/OverlayEntry pair so the suggestion list is
  // drawn as a floating panel anchored right under the field, and a width
  // captured from LayoutBuilder so that panel matches the field's width.
  final _categoryFocusNode = FocusNode();
  final _categoryLayerLink = LayerLink();
  OverlayEntry? _categoryOverlayEntry;
  bool _categoryDropdownOpen = false;
  double _categoryFieldWidth = 0;

  // Selling-price auto-calculation: for a brand-new product, the price is
  // suggested automatically from the cost price plus the store's markup
  // percentage, recalculated live as the cost changes. Once the person
  // types directly into the price field it "unlocks" and stops being
  // overwritten, until they tap the refresh accessory to resync it. When
  // editing an existing product, the saved price is left alone by default
  // since it may not have come from the current markup setting.
  bool _priceManuallyEdited = false;
  bool _syncingPrice = false;

  String? _imagePath;
  bool _recognizingPhoto = false;
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

    // Editing an existing product keeps its saved price untouched unless
    // the person explicitly asks to resync it via the refresh icon.
    _priceManuallyEdited = product != null;

    _categoryFocusNode.addListener(() {
      if (!_categoryFocusNode.hasFocus) _closeCategoryDropdown();
    });
    _cost.addListener(_handleCostChanged);
  }

  @override
  void dispose() {
    _cost.removeListener(_handleCostChanged);
    _name.dispose();
    _category.dispose();
    _cost.dispose();
    _price.dispose();
    _stock.dispose();
    _barcode.dispose();
    _threshold.dispose();
    _categoryOverlayEntry?.remove();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  /// Existing categories drawn from current inventory, deduped and sorted.
  List<String> get _existingCategories {
    final categories =
        widget.store.products
            .map((product) => product.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return categories;
  }

  List<String> _filteredCategories(String query) {
    final categories = _existingCategories;
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return categories;
    return categories
        .where((category) => category.toLowerCase().contains(normalized))
        .toList();
  }

  void _selectCategory(String category) {
    _category.text = category;
    _category.selection = TextSelection.collapsed(offset: category.length);
    _closeCategoryDropdown();
  }

  void _openCategoryDropdown() {
    if (_categoryOverlayEntry != null) {
      _categoryOverlayEntry!.markNeedsBuild();
      return;
    }
    _categoryOverlayEntry = OverlayEntry(
      builder: (context) {
        final categories = _filteredCategories(_category.text);
        return Positioned(
          width: _categoryFieldWidth,
          child: CompositedTransformFollower(
            link: _categoryLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 58),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _category.text.trim().isEmpty
                            ? 'No categories yet. Type to create one.'
                            : 'No match — keep typing to create '
                                  '"${_category.text.trim()}".',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final option = categories[index];
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => _selectCategory(option),
                          );
                        },
                      ),
                    ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_categoryOverlayEntry!);
    setState(() => _categoryDropdownOpen = true);
  }

  void _closeCategoryDropdown() {
    _categoryOverlayEntry?.remove();
    _categoryOverlayEntry = null;
    if (mounted && _categoryDropdownOpen) {
      setState(() => _categoryDropdownOpen = false);
    } else {
      _categoryDropdownOpen = false;
    }
  }

  void _toggleCategoryDropdown() {
    if (_categoryOverlayEntry != null) {
      _closeCategoryDropdown();
    } else {
      _categoryFocusNode.requestFocus();
      _openCategoryDropdown();
    }
  }

  /// Recomputes the selling price from the current cost price and the
  /// store's markup percentage, unless the person has taken manual control
  /// of the price field.
  void _handleCostChanged() {
    if (_priceManuallyEdited) return;
    final cost = double.tryParse(_cost.text);
    if (cost == null || cost < 0) return;
    final computed = widget.store.suggestedSellingPrice(cost);
    _syncingPrice = true;
    _price.text = computed.toStringAsFixed(2);
    _syncingPrice = false;
  }

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

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
      stock: widget.product == null ? int.parse(_stock.text) : null,
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
    if (photo == null || !mounted) return;
    setState(() => _imagePath = photo.path);
    await _suggestProductDetailsFromPhoto(photo.path);
  }

  /// Uses on-device OCR to suggest details from packaging. The editable
  /// fields remain the source of truth when the text is incomplete.
  Future<void> _suggestProductDetailsFromPhoto(String path) async {
    setState(() => _recognizingPhoto = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final suggestion = _suggestFromRecognizedText(recognized);
      if (!mounted || _imagePath != path) return;

      var applied = false;
      setState(() {
        if (_name.text.trim().isEmpty && suggestion.name != null) {
          _name.text = suggestion.name!;
          applied = true;
        }
        if (_category.text.trim().isEmpty && suggestion.category != null) {
          _category.text = suggestion.category!;
          applied = true;
        }
        _recognizingPhoto = false;
      });
      if (applied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Product details suggested from the photo. Please review them.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && _imagePath == path) {
        setState(() => _recognizingPhoto = false);
      }
    } finally {
      await recognizer.close();
    }
  }

  _PhotoSuggestion _suggestFromRecognizedText(RecognizedText recognized) {
    final lines = [
      for (final block in recognized.blocks)
        for (final line in block.lines) _cleanRecognizedLine(line.text),
    ].whereType<String>().toList();
    if (lines.isEmpty) return const _PhotoSuggestion();

    final allText = lines.join(' ').toLowerCase();
    Product? matchingProduct;
    var bestMatchCount = 0;
    for (final product in widget.store.products) {
      final productName = product.name.trim().toLowerCase();
      if (productName.isEmpty) continue;
      if (allText.contains(productName)) {
        matchingProduct = product;
        break;
      }
      final matches = productName
          .split(RegExp(r'\s+'))
          .where((word) => word.length >= 3 && allText.contains(word))
          .length;
      if (matches >= 2 && matches > bestMatchCount) {
        matchingProduct = product;
        bestMatchCount = matches;
      }
    }
    if (matchingProduct != null) {
      return _PhotoSuggestion(
        name: matchingProduct.name,
        category: matchingProduct.category,
      );
    }

    final inferredCategory = _inferCategory(allText);
    final nameLines = lines
        .where(
          (line) =>
              line.length >= 3 &&
              line.length <= 50 &&
              RegExp(r'[A-Za-z]').hasMatch(line) &&
              !RegExp(
                r'^\D*\d+[\d.,]*\s*(g|kg|ml|l|oz|pcs?)?\D*$',
                caseSensitive: false,
              ).hasMatch(line),
        )
        .take(2)
        .toList();
    final name = nameLines.isEmpty ? null : _toTitleCase(nameLines.join(' '));
    return _PhotoSuggestion(name: name, category: inferredCategory);
  }

  String? _cleanRecognizedLine(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isEmpty ? null : clean;
  }

  String? _inferCategory(String text) {
    for (final category in _existingCategories) {
      final normalized = category.trim().toLowerCase();
      if (normalized.length >= 3 && text.contains(normalized)) return category;
    }
    const categories = {
      'Drinks': ['drink', 'juice', 'coffee', 'tea', 'soda', 'water', 'milk'],
      'Snacks': ['snack', 'chips', 'biscuit', 'cookie', 'cracker', 'candy'],
      'Canned Goods': ['canned', 'sardine', 'tuna', 'corned beef'],
      'Pantry': ['rice', 'noodle', 'pasta', 'flour', 'sugar', 'salt'],
      'Personal Care': ['shampoo', 'soap', 'toothpaste', 'lotion'],
      'Household': ['detergent', 'bleach', 'dishwashing', 'tissue'],
    };
    for (final entry in categories.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    return null;
  }

  String _toTitleCase(String value) => value
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

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
                            backgroundColor: AppTheme.mint,
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
            if (_recognizingPhoto)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Reading product label…'),
                  ],
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
            // Category field: looks like a normal text field with a
            // dropdown-arrow accessory on the right. Tapping the icon (or
            // the field itself) opens a floating list of existing
            // categories anchored just below it — tap one to pick it, or
            // keep typing to create a brand-new category if none fits.
            LayoutBuilder(
              builder: (context, constraints) {
                _categoryFieldWidth = constraints.maxWidth;
                return CompositedTransformTarget(
                  link: _categoryLayerLink,
                  child: TextFormField(
                    controller: _category,
                    focusNode: _categoryFocusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g., Drinks, Snacks, Canned Goods',
                      suffixIcon: IconButton(
                        tooltip: 'Choose existing category',
                        onPressed: _toggleCategoryDropdown,
                        icon: AnimatedRotation(
                          turns: _categoryDropdownOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: const Icon(Icons.expand_more_rounded),
                        ),
                      ),
                    ),
                    validator: _required,
                    onTap: () {
                      if (_categoryOverlayEntry == null) {
                        _openCategoryDropdown();
                      }
                    },
                    onChanged: (_) {
                      if (_categoryOverlayEntry != null) {
                        _categoryOverlayEntry!.markNeedsBuild();
                      } else {
                        _openCategoryDropdown();
                      }
                    },
                  ),
                );
              },
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
                    decoration: InputDecoration(
                      labelText: 'Selling Price',
                      prefixText: '₱ ',
                      helperText: _priceManuallyEdited
                          ? 'Manually set'
                          : 'Auto: cost + '
                                '${_formatPercent(widget.store.markupPercent)}%',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        tooltip: 'Recalculate from cost + markup',
                        onPressed: () {
                          setState(() => _priceManuallyEdited = false);
                          _handleCostChanged();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ),
                    onChanged: (_) {
                      if (_syncingPrice) return;
                      if (!_priceManuallyEdited) {
                        setState(() => _priceManuallyEdited = true);
                      }
                    },
                    validator: _money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNew)
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Initial Stock',
                      ),
                      validator: _wholeNumber,
                    ),
                  )
                else
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Current Stock',
                      ),
                      child: Text(
                        '${widget.product!.stock}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
            if (!isNew)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Stock can only be increased from Add stock so each delivery is recorded.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
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
