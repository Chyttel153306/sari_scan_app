import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../utils/barcodes.dart';
import '../services/product_photo_suggestion.dart';
import '../store/app_store.dart';
import '../widgets/product_image.dart';
import '../widgets/catalog_product_card.dart';
import '../widgets/design_system.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid.dart';
import 'barcode_scanner_screen.dart';

/// Manages inventory with search, editing, restocking, and archive actions.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.store, this.addTutorialKey});
  final Key? addTutorialKey;

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

  /// Filters the local catalog by search, category, and archive visibility.
  List<Product> get _products {
    final query = _query.trim().toLowerCase();
    return widget.store.products.where((product) {
      if (!_showArchived && product.isArchived) return false;
      if (_category != 'All' && product.category != _category) return false;
      return query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          matchesBarcodeSearch(product.barcode, query);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Passes the selected product and shared store to the product editor.
  Future<void> _editProduct([Product? product]) async {
    await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDialog(store: widget.store, product: product),
      ),
    );
  }

  /// Opens stock entry and displays the record returned after AppStore updates it.
  Future<void> _addStock(Product product) async {
    final addition = await showDialog<StockAddition>(
      context: context,
      builder: (_) => AddStockDialog(store: widget.store, product: product),
    );
    if (!mounted || addition == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            "{0} added to {1}. Stock: {2}.",
            args: [addition.quantity, product.name, product.stock],
          ),
        ),
      ),
    );
  }

  /// Confirms deletion before AppStore removes the product and queues a local save.
  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Delete product?")),
        content: Text(
          context.tr(
            "Delete {0} from inventory and the cart? Past sales and utang records will be kept. This cannot be undone.",
            args: [product.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr("Cancel")),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr("Delete product")),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.store.deleteProduct(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr("{0} deleted.", args: [product.name]))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store.dataChanges,
      builder: (context, _) => Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // Search and category filters control the inventory list.
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr("Search products..."),
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
                                  category == 'All'
                                      ? context.tr("All Items")
                                      : category,
                                ),
                                labelStyle: TextStyle(
                                  color: _category == category
                                      ? Colors.white
                                      : AppTheme.of(context).muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                selected: _category == category,
                                selectedColor: AppTheme.of(context).emerald,
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
                      context.tr("{0} products", args: [_products.length]),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.of(context).muted,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      context.tr("Show archived"),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  // Include archived products when this switch is enabled.
                  Switch(
                    value: _showArchived,
                    onChanged: (value) => setState(() => _showArchived = value),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_products.isEmpty)
                EmptyState(
                  title: context.tr("No products found."),
                  message: context.tr(
                    "Add a product or try a different search.",
                  ),
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
                      // Each card exposes the actions for this product.
                      return CatalogProductCard(
                        inventory: true,
                        product: product,
                        onEdit: () => _editProduct(product),
                        onAddStock: () => _addStock(product),
                        onArchive: () {
                          final error = widget.store.toggleArchive(product);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr(error))),
                            );
                          }
                        },
                        onDelete: () => _deleteProduct(product),
                      );
                    },
                  ),
                ),
            ],
          ),
          // The plus button opens an empty product form.
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              key: widget.addTutorialKey,
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

/// Records a stock delivery and shows previous stock additions.
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
  bool _submitted = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _quantityValue => int.tryParse(_quantity.text) ?? 0;

  /// Sends the validated stock quantity and note to AppStore and returns the record.
  void _save() {
    if (_submitted || !(_formKey.currentState?.validate() ?? false)) return;
    try {
      final addition = widget.store.addStock(
        product: widget.product,
        quantity: _quantityValue,
        note: _note.text,
      );
      _submitted = true;
      Navigator.pop(context, addition);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.store.stockAdditionsFor(widget.product);
    final afterStock = widget.product.stock + _quantityValue;
    return AlertDialog(
      title: Text(context.tr("Add stock")),
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
                context.tr(
                  "Current stock: {0}  •  After adding: {1}",
                  args: [widget.product.stock, afterStock],
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _quantity,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.tr("Quantity received"),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final quantity = int.tryParse(value ?? '');
                  return quantity == null || quantity <= 0
                      ? context.tr('Enter a quantity greater than zero.')
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr("Delivery / invoice note"),
                  hintText: context.tr("e.g., Supplier invoice #1234"),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr(
                        'Add a delivery or invoice note for the audit trail.',
                      )
                    : null,
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  context.tr("STOCK-IN HISTORY"),
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
          child: Text(context.tr("Cancel")),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_box_outlined),
          label: Text(context.tr("Add stock")),
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

/// Adds or edits a product's photo, details, prices, stock, and barcode.
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
  int _photoReadId = 0;
  String? _suggestedName;
  String? _suggestedCategory;
  String? _photoMessage;
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

  /// Returns unique, sorted categories from inventory for local form suggestions.
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

  /// Filters category suggestions against the text currently typed in the form.
  List<String> _filteredCategories(String query) {
    final categories = _existingCategories;
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return categories;
    return categories
        .where((category) => category.toLowerCase().contains(normalized))
        .toList();
  }

  /// Copies a suggestion into the form; it is stored when the product is saved.
  void _selectCategory(String category) {
    _category.text = category;
    _category.selection = TextSelection.collapsed(offset: category.length);
    _closeCategoryDropdown();
  }

  /// Shows matching inventory categories below the category field.
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
                            ? context.tr(
                                "No categories yet. Type to create one.",
                              )
                            : context.tr(
                                "No match — keep typing to create \"{0}\".",
                                args: [_category.text.trim()],
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.of(context).muted,
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

  /// Removes the floating category suggestions.
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
    if (cost == null || !cost.isFinite || cost < 0) return;
    final computed = widget.store.suggestedSellingPrice(cost);
    if (!computed.isFinite) return;
    _syncingPrice = true;
    _price.text = computed.toStringAsFixed(2);
    _syncingPrice = false;
  }

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  /// Validates the form, prepares the photo, and sends product values to AppStore.
  /// Returns the saved product to the caller after queuing local persistence.
  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Capture validated input before awaiting photo storage/upload.
    final name = _name.text;
    final category = _category.text;
    final cost = double.parse(_cost.text);
    final price = double.parse(_price.text);
    final stock = widget.product == null ? int.parse(_stock.text) : null;
    final barcode = normalizeBarcode(_barcode.text);
    final threshold = int.parse(_threshold.text);
    setState(() => _saving = true);
    // Copy the photo locally and upload to Supabase Storage if linked.
    // The product stores the local file path and the returned Storage path.
    ImportedProductImage imported;
    try {
      imported = await widget.store.importProductImage(
        _imagePath,
        previousPath: widget.product?.imagePath,
        previousUrl: widget.product?.imageUrl,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr("Could not save the product photo: {0}", args: [error]),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    try {
      final savedProduct = widget.store.saveProduct(
        existing: widget.product,
        name: name,
        category: category,
        costPrice: cost,
        price: price,
        stock: stock,
        imagePath: imported.path,
        imageUrl: imported.url,
        barcode: barcode,
        lowStockThreshold: threshold,
      );
      Navigator.pop(context, savedProduct);
    } on ArgumentError catch (error) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  /// Gets a camera or gallery file and uses it for the form preview and local OCR.
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
              title: Text(context.tr("Take a photo")),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr("Choose from gallery")),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (photo == null || !mounted) return;
      _setPhoto(photo.path);
      await _suggestProductDetailsFromPhoto(photo.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Could not save the product photo: {0}', args: [error]),
          ),
        ),
      );
    }
  }

  /// Updates the form photo and clears untouched suggestions from the previous photo.
  void _setPhoto(String? path) {
    setState(() {
      _photoReadId++;
      _imagePath = path;
      _recognizingPhoto = false;
      _photoMessage = null;
      // Clear untouched suggestions when replacing a photo, but keep user edits.
      if (_suggestedName != null && _name.text == _suggestedName) {
        _name.clear();
      }
      if (_suggestedCategory != null && _category.text == _suggestedCategory) {
        _category.clear();
      }
      _suggestedName = null;
      _suggestedCategory = null;
    });
  }

  /// Uses on-device OCR to suggest details from packaging. The editable
  /// fields remain the source of truth when the text is incomplete.
  Future<void> _suggestProductDetailsFromPhoto(String path) async {
    final readId = ++_photoReadId;
    setState(() {
      _recognizingPhoto = true;
      _photoMessage = null;
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      if (!mounted || readId != _photoReadId) return;
      final suggestion = suggestProductFromPhoto(
        recognized,
        products: widget.store.products,
      );

      var applied = false;
      setState(() {
        if (_name.text.trim().isEmpty && suggestion.name != null) {
          _name.text = suggestion.name!;
          _suggestedName = suggestion.name;
          applied = true;
        }
        if (_category.text.trim().isEmpty && suggestion.category != null) {
          _category.text = suggestion.category!;
          _suggestedCategory = suggestion.category;
          applied = true;
        }
        _recognizingPhoto = false;
        _photoMessage = applied
            ? 'Name suggested. Check the brand, variant, and size.'
            : suggestion.name == null
            ? 'No clear name found. Retake the front label or enter it manually.'
            : null;
      });
    } catch (_) {
      if (mounted && readId == _photoReadId) {
        setState(() {
          _recognizingPhoto = false;
          _photoMessage = 'Could not read the label. Enter the name manually.';
        });
      }
    } finally {
      await recognizer.close();
    }
  }

  /// Copies the scanner's returned barcode into the form for later product saving.
  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );
    if (!mounted) return;
    if (barcode != null && normalizeBarcode(barcode).isNotEmpty) {
      _barcode.text = normalizeBarcode(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isNew = widget.product == null;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          isNew ? context.tr("Add New Product") : context.tr("Edit Product"),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isNew
                      ? context.tr("Enter details for the new inventory item.")
                      : context.tr("Update this inventory item."),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr("PRODUCT IMAGE"),
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
                                backgroundColor: AppTheme.of(context).mint,
                                child: Icon(
                                  Icons.add_a_photo_outlined,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(context.tr("Upload Product Photo")),
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
                                  tooltip: context.tr("Remove photo"),
                                  onPressed: () => _setPhoto(null),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_recognizingPhoto)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(context.tr("Reading product label…")),
                      ],
                    ),
                  ),
                if (_photoMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      context.tr(_photoMessage!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.tr("Product Name"),
                    hintText: context.tr("e.g., Bear Brand Fortified 320g"),
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
                          labelText: context.tr("Category"),
                          hintText: context.tr(
                            "e.g., Drinks, Snacks, Canned Goods",
                          ),
                          suffixIcon: IconButton(
                            tooltip: context.tr("Choose existing category"),
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
                        decoration: InputDecoration(
                          labelText: context.tr("Cost Price"),
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
                          labelText: context.tr("Selling Price"),
                          prefixText: '₱ ',
                          helperText: _priceManuallyEdited
                              ? context.tr("Manually set")
                              : context.tr(
                                  "Auto: cost + {0}%",
                                  args: [
                                    _formatPercent(widget.store.markupPercent),
                                  ],
                                ),
                          helperMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: context.tr(
                              "Recalculate from cost + markup",
                            ),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: context.tr("Initial Stock"),
                          ),
                          validator: _wholeNumber,
                        ),
                      )
                    else
                      Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.tr("Current Stock"),
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: context.tr("Min Stock Alert"),
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
                      context.tr(
                        "Stock can only be increased from Add stock so each delivery is recorded.",
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _barcode,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: context.tr("Barcode (optional)"),
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    suffixIcon: IconButton(
                      tooltip: context.tr("Scan barcode with camera"),
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ),
                  validator: (value) {
                    final barcode = value?.trim() ?? '';
                    if (barcode.isEmpty) return null;
                    final duplicate =
                        widget.product?.isArchived != true &&
                        widget.store.findByBarcode(
                              barcode,
                              excluding: widget.product,
                            ) !=
                            null;
                    return duplicate
                        ? context.tr(
                            'Another active product already uses this barcode.',
                          )
                        : null;
                  },
                ),
              ],
            ),
          ),
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
                  child: Text(context.tr("CANCEL")),
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
                    label: Text(
                      _saving
                          ? context.tr("SAVING...")
                          : context.tr("SAVE PRODUCT"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rejects an empty required form field before values reach AppStore.
  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr('This field is required.')
      : null;

  /// Rejects missing, non-finite, or negative prices before saving.
  String? _money(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number < 0
        ? context.tr('Enter a valid amount.')
        : null;
  }

  /// Rejects invalid or negative inventory quantities before saving.
  String? _wholeNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? context.tr('Enter 0 or more.') : null;
  }
}
