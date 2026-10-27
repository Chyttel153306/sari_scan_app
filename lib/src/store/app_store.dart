import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../utils/money.dart';
import '../services/snapshot_validation.dart';
import '../l10n/app_language.dart';
import '../utils/barcodes.dart';
import '../theme/theme_choice.dart';
import '../models/sales_trend.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_image_service.dart';
import '../services/supabase_sync_service.dart';

/// The outcome of a cloud sync operation, surfaced to the UI so it can show
/// a confirmation or an error without the store needing to throw.
class CloudSyncResult {
  const CloudSyncResult.success(this.syncCode, {this.warning}) : error = null;
  const CloudSyncResult.failure(this.error) : syncCode = null, warning = null;

  final String? syncCode;
  final String? error;
  final String? warning;

  bool get isSuccess => error == null;
}

/// The local file and (optionally) the Supabase Storage path produced when a
/// product photo is imported. [url] is null when no image sync service is
/// configured, or when uploading failed — the photo still works fine on
/// this phone either way, it just won't follow the product to other
/// phones over sync.
class ImportedProductImage {
  const ImportedProductImage({required this.path, required this.url});

  final String? path;
  final String? url;
}

typedef _StoreData = ({
  List<Product> products,
  List<Customer> customers,
  List<SaleRecord> sales,
  List<StockAddition> additions,
  double markup,
});

/// Holds live app data. Changes are saved to LocalStorageService; Settings
/// actions exchange store snapshots with SupabaseSyncService. Photo files
/// use SupabaseImageService separately from the snapshot JSON.
class AppStore extends ChangeNotifier {
  AppStore({
    List<Product>? products,
    List<Customer>? customers,
    this.storage,
    this.cloudSync,
    this.imageSync,
    double? markupPercent,
  }) : products = products ?? [],
       customers = customers ?? [],
       markupPercent = markupPercent ?? _defaultMarkupPercent;

  /// Creates the store with local persistence and optional cloud services.
  factory AppStore.forApp({
    LocalStorageService? storage,
    SupabaseSyncService? cloudSync,
    SupabaseImageService? imageSync,
  }) {
    return AppStore(
      storage: storage,
      cloudSync: cloudSync,
      imageSync: imageSync,
    );
  }

  static const _dataVersion = 3;

  // Default markup applied on top of a product's cost price to suggest a
  // selling price. Configurable from the Settings screen and persisted
  // alongside the rest of the store's data.
  static const _defaultMarkupPercent = 10.0;

  final List<Product> products;
  final List<Customer> customers;
  final List<SaleRecord> sales = [];
  final List<StockAddition> stockAdditions = [];
  final Map<String, int> _cart = {};
  final LocalStorageService? storage;

  // Optional: lets multiple phones for the same store manually push/pull
  // their data through Supabase. Entirely separate from [storage] — the
  // app is fully usable offline whether or not this is configured.
  final SupabaseSyncService? cloudSync;

  // Optional: mirrors product photos to Supabase Storage so they follow the product
  // across phones during cloud sync, since [storage]'s local file paths
  // only ever resolve on the phone that took the picture. Photos still
  // work fine locally with this left unset — they just won't sync.
  final SupabaseImageService? imageSync;

  Future<void> _persistenceQueue = Future.value();
  Future<String?> _lastQueuedSave = Future.value(null);
  Future<void> _photoRestoration = Future.value();
  Future<void> get photoRestorationSettled => _photoRestoration;
  bool _disposed = false;
  bool _syncInProgress = false;
  bool _loadFailed = false;
  int _revision = 0;

  String? currentUserName;
  String? storageError;
  bool isLoading = false;
  Map<String, dynamic>? _account;
  double markupPercent;
  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  ThemeChoice _themeChoice = ThemeChoice.defaultTheme;
  ThemeChoice get themeChoice => _themeChoice;

  // Cloud sync state, persisted locally so the pairing survives app
  // restarts without needing to sync again.
  String? syncCode;
  DateTime? lastSyncedAt;
  String? photoSyncWarning;

  bool _tutorialDismissed = false;
  bool get needsFirstUseTutorial => !_tutorialDismissed;

  /// Saves this phone's completed tutorial preference.
  Future<String?> dismissTutorial() async {
    _tutorialDismissed = true;
    notifyListeners();
    return _saveNow();
  }

  bool get isAuthenticated => currentUserName != null;
  bool get hasLocalAccount => _account != null;
  String? get registeredOwnerName =>
      _account == null ? null : '${_account!['name']}';
  bool get isLocalStorageEnabled => storage != null;
  bool get isCloudSyncAvailable => cloudSync != null;
  bool get isImageSyncAvailable => imageSync != null;
  Future<void> get persistenceSettled => _persistenceQueue;

  final ChangeNotifier _dataChanges = ChangeNotifier();

  /// Store updates excluding cart quantity changes. Catalogs, reports and the
  /// app shell do not need to rebuild when a cashier adds an item to the cart.
  Listenable get dataChanges => _dataChanges;

  @override
  void notifyListeners() {
    if (_disposed) return;
    _dataChanges.notifyListeners();
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _dataChanges.dispose();
    imageSync?.dispose();
    super.dispose();
  }

  /// Returns in-memory products available for sale.
  List<Product> get activeProducts =>
      products.where((product) => !product.isArchived).toList();

  /// Returns saved stock-in records for the product's inventory history.
  List<StockAddition> stockAdditionsFor(Product product) => stockAdditions
      .where((addition) => addition.productId == product.id)
      .toList();

  /// Combines in-memory cart quantities with current product records.
  List<CartLine> get cartLines => _cart.entries
      .map(
        (entry) => CartLine(
          product: products.firstWhere((product) => product.id == entry.key),
          quantity: entry.value,
        ),
      )
      .toList();

  int get cartItemCount =>
      _cart.values.fold(0, (total, quantity) => total + quantity);

  double get cartTotal => roundMoney(
    cartLines.fold<double>(0, (total, line) => total + line.subtotal),
  );

  /// Sums customer ledger balances for the total unpaid utang.
  double get totalOutstanding =>
      customers.fold(0, (total, customer) => total + customer.balance);

  /// Suggested selling price for a given cost price, using the current
  /// markup percentage (cost + markup%).
  double suggestedSellingPrice(double costPrice) =>
      costPrice * (1 + markupPercent / 100);

  /// Loads local JSON into the store, saves migrations, and restores missing photos.
  Future<void> initialize() async {
    if (storage == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final snapshot = await storage!.loadSnapshot();
      if (snapshot != null) {
        final migrated = _restoreSnapshot(snapshot);
        if (migrated) await storage!.saveSnapshot(_snapshot());
      }
      _loadFailed = false;
      _photoRestoration = _restorePhotosInBackground();
      storageError = null;
    } catch (error) {
      _loadFailed = true;
      storageError = 'Local data could not be loaded: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Downloads missing photos to local storage and saves their new local paths.
  Future<void> _restorePhotosInBackground() async {
    final previous = {for (final p in products) p: p.imagePath};
    try {
      await _hydrateMissingProductImages();
      if (_disposed) return;
      if (products.any(
        (p) => previous.containsKey(p) && previous[p] != p.imagePath,
      )) {
        await _saveNow();
      } else {
        notifyListeners();
      }
    } catch (error) {
      if (_disposed) return;
      photoSyncWarning = 'Photos could not be restored: $error';
      notifyListeners();
    }
  }

  /// Checks entered text against the owner name stored on this phone.
  String? validateOwnerName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return 'Enter your name.';
    final account = _account;
    if (account != null &&
        '${account['name']}'.trim().toLowerCase() != normalized.toLowerCase()) {
      return 'That name does not match the owner registered on this phone.';
    }
    return null;
  }

  /// Saves the owner name locally and opens an in-memory session on success.
  /// The caller must complete phone authentication before calling this.
  Future<String?> openSecureSession(String name) async {
    final validation = validateOwnerName(name);
    if (validation != null) return validation;
    final normalized = name.trim();
    final previous = _account;
    _account ??= {'name': normalized};
    final error = await _saveNow();
    if (error != null) {
      _account = previous;
    } else {
      currentUserName = '${_account!['name']}';
    }
    notifyListeners();
    return error;
  }

  /// Saves the new owner name locally and restores the old name if saving fails.
  Future<String?> renameOwner(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return 'Enter a store name.';
    if (_account == null) return 'No store is registered on this phone yet.';
    final previous = _account!['name'];
    _account!['name'] = normalized;
    final error = await _saveNow();
    if (error != null && _account?['name'] == normalized) {
      _account!['name'] = previous;
    }
    if (error == null && currentUserName != null) {
      currentUserName = registeredOwnerName;
    }
    notifyListeners();
    return error;
  }

  /// Updates the default markup percentage used to suggest selling prices.
  Future<String?> updateMarkupPercent(double percent) async {
    if (!percent.isFinite || percent < 0) {
      return 'Enter a valid percentage of 0 or more.';
    }
    final previous = markupPercent;
    markupPercent = percent;
    notifyListeners();
    final error = await _saveNow();
    if (error != null && markupPercent == percent) {
      markupPercent = previous;
      notifyListeners();
    }
    return error;
  }

  /// Applies and saves this phone's theme; restores it if the save fails.
  Future<String?> updateTheme(ThemeChoice choice) async {
    final previous = _themeChoice;
    _themeChoice = choice;
    notifyListeners();
    final error = await _saveNow();
    if (error != null && _themeChoice == choice) {
      _themeChoice = previous;
      notifyListeners();
    }
    return error;
  }

  /// Language is a preference for this phone and is excluded from cloud sync.
  Future<String?> updateLanguage(AppLanguage language) async {
    final previous = _language;
    _language = language;
    notifyListeners();
    final error = await _saveNow();
    if (error != null && _language == language) {
      _language = previous;
      notifyListeners();
    }
    return error;
  }

  /// Clears the session and in-memory cart while retaining saved records.
  Future<void> logout() async {
    _revision++;
    currentUserName = null;
    _cart.clear();
    notifyListeners();
  }

  /// Adds one unit to the in-memory cart, limited by available stock.
  void addToCart(Product product) {
    if (product.isArchived || !products.contains(product)) return;
    final current = _cart[product.id] ?? 0;
    if (current >= product.stock) return;
    _cart[product.id] = current + 1;
    _revision++;
    super.notifyListeners();
  }

  /// Reduces the in-memory cart quantity and removes empty lines.
  void removeOneFromCart(Product product) {
    final current = _cart[product.id] ?? 0;
    if (current <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current - 1;
    }
    _revision++;
    super.notifyListeners();
  }

  /// Removes the product's entire line from the in-memory cart.
  void removeFromCart(Product product) {
    _cart.remove(product.id);
    _revision++;
    super.notifyListeners();
  }

  /// Searches active products locally by exact or equivalent retail barcode.
  Product? findByBarcode(String barcode, {Product? excluding}) {
    final normalized = normalizeBarcode(barcode);
    if (normalized.isEmpty) return null;
    // Prefer an exact match for older catalogs containing equivalent codes.
    for (final product in activeProducts) {
      if (product != excluding &&
          normalizeBarcode(product.barcode) == normalized) {
        return product;
      }
    }
    final key = barcodeKey(normalized);
    for (final product in activeProducts) {
      if (product != excluding && barcodeKey(product.barcode) == key) {
        return product;
      }
    }
    return null;
  }

  /// Validates product values, updates inventory, and queues a local JSON save.
  /// Photo copying and upload happen separately before this call.
  Product saveProduct({
    Product? existing,
    required String name,
    required String category,
    required double price,
    int? stock,
    double? costPrice,
    String? imagePath,
    String? imageUrl,
    required String barcode,
    required int lowStockThreshold,
  }) {
    if (existing != null && !products.contains(existing)) {
      throw ArgumentError('Product is no longer in inventory.');
    }
    if (name.trim().isEmpty || category.trim().isEmpty) {
      throw ArgumentError('Product name and category are required.');
    }
    if (!price.isFinite ||
        price < 0 ||
        (costPrice != null && (!costPrice.isFinite || costPrice < 0))) {
      throw ArgumentError('Enter a valid non-negative price.');
    }
    if (lowStockThreshold < 0 ||
        (existing == null && (stock == null || stock < 0))) {
      throw ArgumentError('Stock and minimum stock must be zero or more.');
    }
    if (existing?.isArchived != true &&
        findByBarcode(barcode, excluding: existing) != null) {
      throw ArgumentError('Another active product already uses this barcode.');
    }
    late final Product savedProduct;
    if (existing == null) {
      if (stock == null) {
        throw ArgumentError.value(stock, 'stock', 'Initial stock is required.');
      }
      savedProduct = Product(
        id: _nextId(products.map((product) => product.id)),
        name: name.trim(),
        category: category.trim(),
        price: price,
        stock: stock,
        costPrice: costPrice,
        imagePath: imagePath,
        imageUrl: imageUrl,
        barcode: normalizeBarcode(barcode),
        lowStockThreshold: lowStockThreshold,
      );
      products.add(savedProduct);
      if (stock > 0) {
        stockAdditions.insert(
          0,
          StockAddition(
            id: _nextId(stockAdditions.map((entry) => entry.id)),
            productId: savedProduct.id,
            productName: savedProduct.name,
            quantity: stock,
            createdAt: DateTime.now(),
            addedBy: currentUserName ?? 'Unknown user',
            note: 'Initial stock when product was created',
          ),
        );
      }
    } else {
      existing
        ..name = name.trim()
        ..category = category.trim()
        ..price = price
        ..costPrice = costPrice
        ..imagePath = imagePath
        ..imageUrl = imageUrl
        ..barcode = normalizeBarcode(barcode)
        ..lowStockThreshold = lowStockThreshold;
      savedProduct = existing;
    }
    notifyListeners();
    _queueSave();
    return savedProduct;
  }

  /// Adds received stock without allowing a product edit to overwrite the
  /// current count. Every addition has a required source note and audit trail.
  StockAddition addStock({
    required Product product,
    required int quantity,
    required String note,
  }) {
    if (!products.contains(product)) {
      throw ArgumentError.value(
        product,
        'product',
        'Product is not in inventory.',
      );
    }
    if (product.isArchived) {
      throw ArgumentError.value(
        product,
        'product',
        'Archived products cannot receive stock.',
      );
    }
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Quantity must be greater than zero.',
      );
    }
    final normalizedNote = note.trim();
    if (normalizedNote.isEmpty) {
      throw ArgumentError.value(note, 'note', 'A stock-in note is required.');
    }

    final updatedStock = product.stock + quantity;
    if (updatedStock < product.stock) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Stock quantity is too large.',
      );
    }
    final addition = StockAddition(
      id: _nextId(stockAdditions.map((entry) => entry.id)),
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      createdAt: DateTime.now(),
      addedBy: currentUserName ?? 'Unknown user',
      note: normalizedNote,
    );
    product.stock = updatedStock;
    stockAdditions.insert(0, addition);
    notifyListeners();
    _queueSave();
    return addition;
  }

  /// Changes availability, removes the cart line, and queues a local save.
  String? toggleArchive(Product product) {
    if (product.isArchived &&
        findByBarcode(product.barcode, excluding: product) != null) {
      return 'Another active product already uses this barcode. Edit it before restoring.';
    }
    product.isArchived = !product.isArchived;
    _cart.remove(product.id);
    notifyListeners();
    _queueSave();
    return null;
  }

  /// Removes inventory and cart entries and queues a local save; history is kept.
  void deleteProduct(Product product) {
    _cart.remove(product.id);
    products.removeWhere((item) => item.id == product.id);
    // Sales and credit ledgers keep their own saved product details.
    notifyListeners();
    _queueSave();
  }

  /// Adds customer contact details and queues a local snapshot save.
  Customer addCustomer(String name, String phone) {
    final customer = Customer(
      id: _nextId(customers.map((customer) => customer.id)),
      name: name.trim(),
      phone: phone.trim(),
    );
    customers.add(customer);
    notifyListeners();
    _queueSave();
    return customer;
  }

  /// Imports [sourcePath] into local storage and, if an image sync
  /// service is configured and this phone is linked to a cloud store,
  /// uploads it to Supabase Storage so the photo can follow the product to
  /// other phones during cloud sync. Upload failures are swallowed — the
  /// photo still works fine on this phone, it just won't sync this time.
  ///
  /// Photos live under the store's sync-code folder, so they can only be
  /// uploaded once cloud sync has been set up. Photos saved before that are
  /// picked up later by [backfillProductImages].
  ///
  /// When the photo is unchanged from [previousPath] but was never
  /// uploaded, this backfills it by uploading the existing local file.
  /// Previous images remain available because older local and cloud snapshots
  /// can still reference them. Importing prepares a photo before the product
  /// save has been validated; it must not delete the last committed photo.
  Future<ImportedProductImage> importProductImage(
    String? sourcePath, {
    String? previousPath,
    String? previousUrl,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      // Older local/cloud snapshots may still reference the previous image.
      return const ImportedProductImage(path: null, url: null);
    }
    if (sourcePath == previousPath || storage == null) {
      final url = previousUrl ?? await _uploadImageIfLinked(sourcePath);
      return ImportedProductImage(path: sourcePath, url: url);
    }
    final imported = await storage!.importProductImage(sourcePath);
    final uploadedUrl = await _uploadImageIfLinked(imported);
    return ImportedProductImage(path: imported, url: uploadedUrl);
  }

  /// Uploads a local photo to the linked Supabase folder, or returns null on failure.
  Future<String?> _uploadImageIfLinked(String localPath) async {
    final sync = imageSync;
    final code = syncCode;
    if (sync == null || code == null) return null;
    try {
      return await sync.uploadImage(localPath, syncCode: code);
    } catch (_) {
      return null;
    }
  }

  /// Uploads every existing product photo that is not in Supabase Storage
  /// yet — products whose photo was added before photo sync existed, and
  /// products still pointing at a legacy ImgBB URL. One tap brings an
  /// entire existing catalog's photos into sync. Requires this phone to
  /// be linked to a cloud store. Returns how many photos were uploaded.
  Future<int> backfillProductImages() async {
    photoSyncWarning = null;
    final sync = imageSync;
    final code = syncCode;
    if (sync == null || code == null) return 0;
    var uploaded = 0;
    var failed = 0;
    Object? firstError;
    for (final product in List<Product>.of(products)) {
      final current = product.imageUrl;
      final needsUpload =
          current == null ||
          current.isEmpty ||
          SupabaseImageService.isLegacyUrl(current) ||
          !current.startsWith('$code/');
      if (!needsUpload) continue;
      try {
        var path = product.imagePath;
        final hasLocalFile =
            path != null && path.isNotEmpty && await File(path).exists();
        if (!hasLocalFile) {
          // Fetch an existing remote copy before moving it into this store.
          if (current == null || current.isEmpty || storage == null) {
            if (path == null || path.isEmpty) continue;
            throw const FileSystemException('The original photo is missing.');
          }
          final bytes = await sync.downloadImageBytes(current);
          path = await storage!.saveImageBytes(bytes);
          product.imagePath = path;
        }
        product.imageUrl = await sync.uploadImage(path, syncCode: code);
        uploaded++;
      } catch (error) {
        failed++;
        firstError ??= error;
      }
    }
    if (failed > 0) {
      photoSyncWarning =
          '$failed photo(s) could not upload: $firstError. '
          'Retry Upload changes on this phone.';
    }
    if (uploaded > 0) {
      notifyListeners();
      await _saveNow();
    }
    return uploaded;
  }

  /// Waits for the local payment save and removes the new ledger entry if it fails.
  Future<String?> recordPaymentAndSave(Customer customer, double amount) async {
    final validation = recordPayment(customer, amount);
    if (validation != null) return validation;
    final payment = customer.ledger.first;
    final error = await _lastQueuedSave;
    if (error != null) {
      customer.ledger.remove(payment);
      _revision++;
      notifyListeners();
    }
    return error;
  }

  /// Adds a validated repayment to the customer's ledger and queues a local save.
  String? recordPayment(Customer customer, double amount) {
    if (!customers.contains(customer)) {
      return 'Customer is no longer in this store.';
    }
    if (!amount.isFinite || amount <= 0) {
      return 'Enter a valid payment greater than zero.';
    }
    if (amount > customer.balance) {
      return 'Payment cannot be greater than the outstanding balance.';
    }
    customer.ledger.insert(
      0,
      LedgerEntry(
        id: _nextId(customer.ledger.map((entry) => entry.id)),
        createdAt: DateTime.now(),
        type: LedgerEntryType.payment,
        amount: amount,
        note: 'Customer payment',
      ),
    );
    notifyListeners();
    _queueSave();
    return null;
  }

  /// Waits for checkout to save locally; restores stock, cart, and ledger on failure.
  Future<SaleRecord> completeSaleAndSave({
    required PaymentType paymentType,
    double amountReceived = 0,
    Customer? customer,
  }) async {
    final lines = cartLines;
    final sale = completeSale(
      paymentType: paymentType,
      amountReceived: amountReceived,
      customer: customer,
    );
    final error = await _lastQueuedSave;
    if (error == null) return sale;
    sales.remove(sale);
    if (paymentType == PaymentType.utang) {
      customer?.ledger.removeWhere(
        (entry) =>
            entry.saleId == sale.id && entry.type == LedgerEntryType.credit,
      );
    }
    for (final line in lines) {
      if (!products.contains(line.product)) continue;
      line.product.stock += line.quantity;
      if (!line.product.isArchived) {
        final quantity = (_cart[line.product.id] ?? 0) + line.quantity;
        _cart[line.product.id] = quantity > line.product.stock
            ? line.product.stock
            : quantity;
      }
    }
    _revision++;
    notifyListeners();
    throw StateError(error);
  }

  /// Converts the cart into sale history, reduces stock, and records any utang debt.
  /// Clears the cart and queues all changed records for local persistence.
  SaleRecord completeSale({
    required PaymentType paymentType,
    double amountReceived = 0,
    Customer? customer,
  }) {
    if (_cart.isEmpty) throw StateError('The cart is empty.');
    if (paymentType == PaymentType.cash &&
        (!amountReceived.isFinite || amountReceived < 0)) {
      throw StateError('Enter a valid cash amount.');
    }
    if (paymentType == PaymentType.cash && amountReceived < cartTotal) {
      throw StateError('The cash amount is insufficient.');
    }
    if (paymentType == PaymentType.utang &&
        (customer == null || !customers.contains(customer))) {
      throw StateError('Select a customer for an utang sale.');
    }

    final lines = cartLines;
    if (lines.any(
      (line) =>
          line.product.isArchived ||
          line.quantity <= 0 ||
          line.quantity > line.product.stock ||
          !line.product.price.isFinite ||
          line.product.price < 0,
    )) {
      throw StateError('Stock or product details changed. Review the cart.');
    }
    final total = cartTotal;
    if (!total.isFinite) throw StateError('The cart total is invalid.');
    final now = DateTime.now();
    final sale = SaleRecord(
      id: _nextId(sales.map((sale) => sale.id)),
      createdAt: now,
      items: cartLines
          .map(
            (line) => SaleItem(
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.price,
              unitCost: line.product.costPrice,
            ),
          )
          .toList(),
      total: total,
      paymentType: paymentType,
      amountReceived: paymentType == PaymentType.cash ? amountReceived : 0,
      change: paymentType == PaymentType.cash
          ? roundMoney(amountReceived - total)
          : 0,
      customerId: customer?.id,
    );

    for (final line in cartLines) {
      line.product.stock -= line.quantity;
    }
    sales.insert(0, sale);

    if (paymentType == PaymentType.utang && customer != null) {
      customer.ledger.insert(
        0,
        LedgerEntry(
          id: _nextId(customer.ledger.map((entry) => entry.id)),
          createdAt: now,
          type: LedgerEntryType.credit,
          amount: total,
          note: 'Utang sale ${sale.id}',
          saleId: sale.id,
        ),
      );
    }

    _cart.clear();
    notifyListeners();
    _queueSave();
    return sale;
  }

  /// Filters in-memory sale history for the report period and reference time.
  List<SaleRecord> salesFor(ReportPeriod period, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final start = reportStart(period, reference);
    return sales
        .where(
          (sale) =>
              !sale.createdAt.isBefore(start) &&
              !sale.createdAt.isAfter(reference),
        )
        .toList();
  }

  // ---------------------------------------------------------------------
  // Store snapshot sync is manual from Settings. Photo uploads can also run
  // when saving a product, and missing photos can download during startup.
  // ---------------------------------------------------------------------

  /// Creates a brand-new cloud store from this phone's current data and
  /// returns the sync code other phones can use to join it.
  Future<CloudSyncResult> startCloudSync() => _runSync(_startCloudSync);
  /// Joins by code and replaces local store records with the cloud snapshot.
  Future<CloudSyncResult> joinCloudSync(String code) =>
      _runSync(() => _joinCloudSync(code));
  /// Replaces the linked cloud snapshot with this phone's store records.
  Future<CloudSyncResult> pushToCloud() => _runSync(_pushToCloud);
  /// Replaces this phone's store records with the linked cloud snapshot.
  Future<CloudSyncResult> pullFromCloud() => _runSync(_pullFromCloud);

  /// Runs one snapshot sync at a time and blocks sync after local loading fails.
  Future<CloudSyncResult> _runSync(
    Future<CloudSyncResult> Function() operation,
  ) async {
    if (_syncInProgress) {
      return const CloudSyncResult.failure(
        'A sync operation is already in progress.',
      );
    }
    if (_loadFailed) return CloudSyncResult.failure(storageError);
    _syncInProgress = true;
    try {
      return await operation();
    } finally {
      _syncInProgress = false;
    }
  }

  /// Creates the cloud snapshot, saves the code locally, then uploads photos and records.
  Future<CloudSyncResult> _startCloudSync() async {
    final cloud = cloudSync;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    try {
      final code = await cloud.createSyncCode(_cloudSnapshot());
      syncCode = code;
      lastSyncedAt = DateTime.now();
      notifyListeners();
      final error = await _saveNow();
      if (error != null) return CloudSyncResult.failure(error);
      // Creating the store first grants access to its private photo folder.
      return await _pushToCloud();
    } catch (error) {
      return CloudSyncResult.failure('Could not start cloud sync: $error');
    }
  }

  /// Joins an existing cloud store using a code from another phone,
  /// replacing this phone's local data with the cloud copy.
  Future<CloudSyncResult> _joinCloudSync(String code) async {
    final cloud = cloudSync;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const CloudSyncResult.failure('Enter a sync code.');
    }
    try {
      final revision = _revision;
      final remote = await cloud.downloadSnapshot(normalized, join: true);
      if (remote == null) {
        return const CloudSyncResult.failure(
          'No store was found for that sync code.',
        );
      }
      await _installCloudSnapshot(remote, revision, normalized);
      return CloudSyncResult.success(normalized, warning: photoSyncWarning);
    } catch (error) {
      return CloudSyncResult.failure('Could not join cloud sync: $error');
    }
  }

  /// Pushes this phone's current data to the cloud, overwriting it.
  Future<CloudSyncResult> _pushToCloud() async {
    final cloud = cloudSync;
    final code = syncCode;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    if (code == null) {
      return const CloudSyncResult.failure('Set up sync first.');
    }
    try {
      // Restore membership before accessing the private photo folder.
      await cloud.downloadSnapshot(code);
      await backfillProductImages();
      final uploadedAt = await cloud.uploadSnapshot(
        syncCode: code,
        snapshot: _cloudSnapshot(),
      );
      lastSyncedAt = uploadedAt;
      notifyListeners();
      final error = await _saveNow();
      if (error != null) return CloudSyncResult.failure(error);
      return CloudSyncResult.success(code, warning: photoSyncWarning);
    } catch (error) {
      return CloudSyncResult.failure('Could not upload to cloud: $error');
    }
  }

  /// Pulls the latest cloud data down, overwriting this phone's data.
  Future<CloudSyncResult> _pullFromCloud() async {
    final cloud = cloudSync;
    final code = syncCode;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    if (code == null) {
      return const CloudSyncResult.failure('Set up sync first.');
    }
    try {
      final revision = _revision;
      final remote = await cloud.downloadSnapshot(code);
      if (remote == null) {
        return const CloudSyncResult.failure(
          'No cloud data was found for this sync code.',
        );
      }
      await _installCloudSnapshot(remote, revision, code);
      return CloudSyncResult.success(code, warning: photoSyncWarning);
    } catch (error) {
      return CloudSyncResult.failure('Could not download from cloud: $error');
    }
  }

  /// Clears this phone's store and photo cache. The cloud store and the
  /// device's owner login remain available so the code can be joined again.
  Future<String?> leaveCloudSync() async {
    if (_syncInProgress) return 'A sync operation is already in progress.';
    if (_loadFailed) return storageError;
    _syncInProgress = true;
    try {
      return await _leaveCloudSync();
    } finally {
      _syncInProgress = false;
    }
  }

  /// Clears and saves local records, then removes cached photos; cloud data is kept.
  /// Restores prior records if the local save fails.
  Future<String?> _leaveCloudSync() async {
    final previous = _currentData();
    final previousCart = Map<String, int>.of(_cart);
    final previousCode = syncCode;
    final previousTime = lastSyncedAt;
    final previousWarning = photoSyncWarning;
    products.clear();
    customers.clear();
    sales.clear();
    stockAdditions.clear();
    _cart.clear();
    markupPercent = _defaultMarkupPercent;
    syncCode = null;
    lastSyncedAt = null;
    photoSyncWarning = null;
    notifyListeners();
    final error = await _saveNow();
    if (error != null) {
      _replaceData(previous);
      _cart.addAll(previousCart);
      syncCode = previousCode;
      lastSyncedAt = previousTime;
      photoSyncWarning = previousWarning;
      notifyListeners();
      return error;
    }
    try {
      await storage?.clearProductImages();
      return null;
    } catch (error) {
      return 'Store unlinked, but some cached photos could not be removed: $error';
    }
  }

  /// Downloads and locally caches any product photo whose local file is
  /// missing but whose [Product.imageUrl] is set — the normal situation
  /// right after joining or pulling a cloud snapshot on a phone that
  /// never had that photo locally, or on first launch after restoring an
  /// old local snapshot whose image files no longer exist. Failures are
  /// reported in [photoSyncWarning] and retried on the next sync.
  Future<void> _hydrateMissingProductImages({List<Product>? targets}) async {
    photoSyncWarning = null;
    final sync = imageSync;
    final localStorage = storage;
    if (sync == null || localStorage == null) return;
    var failed = 0;
    Object? firstError;
    for (final product in List<Product>.of(targets ?? products)) {
      final url = product.imageUrl;
      if (url == null || url.isEmpty) continue;
      final path = product.imagePath;
      if (path != null && await File(path).exists()) continue;
      try {
        final bytes = await sync.downloadImageBytes(url);
        product.imagePath = await localStorage.saveImageBytes(bytes);
      } catch (error) {
        failed++;
        firstError ??= error;
      }
    }
    if (failed > 0) {
      photoSyncWarning =
          '$failed photo(s) could not download: $firstError. '
          'Retry Download latest on this phone.';
    }
  }

  /// Validates local or cloud JSON and returns model lists without changing
  /// live state. The caller decides when to install the decoded records.
  _StoreData _decodeSnapshot(Map<String, dynamic> snapshot) {
    validateStoreSnapshot(snapshot);
    return (
      products: _mapRows(snapshot['products']).map(_productFromRow).toList(),
      customers: _mapRows(snapshot['customers']).map(_customerFromRow).toList(),
      sales: _mapRows(snapshot['sales']).map(_saleFromRow).toList(),
      additions: _mapRows(
        snapshot['stock_additions'],
      ).map(_stockAdditionFromRow).toList(),
      markup:
          (snapshot['markup_percent'] as num?)?.toDouble() ??
          _defaultMarkupPercent,
    );
  }

  /// Copies the current lists for rollback; the model objects are shared.
  _StoreData _currentData() => (
    products: List.of(products),
    customers: List.of(customers),
    sales: List.of(sales),
    additions: List.of(stockAdditions),
    markup: markupPercent,
  );

  /// Replaces in-memory record lists and markup; the caller handles persistence.
  void _replaceData(_StoreData data) {
    products
      ..clear()
      ..addAll(data.products);
    customers
      ..clear()
      ..addAll(data.customers);
    sales
      ..clear()
      ..addAll(data.sales);
    stockAdditions
      ..clear()
      ..addAll(data.additions);
    markupPercent = data.markup;
  }

  /// Validates cloud records, caches photos, and saves the replacement locally.
  /// Rejects concurrent edits and restores prior state when the save fails.
  Future<void> _installCloudSnapshot(
    CloudSnapshot remote,
    int revision,
    String code,
  ) async {
    final data = _decodeSnapshot(remote.data);
    final localPhotos = <String, String>{
      for (final p in products)
        if (p.imageUrl != null && p.imagePath != null)
          p.imageUrl!: p.imagePath!,
    };
    for (final p in data.products) {
      // Paths from another phone are never accepted as local file paths.
      p.imagePath = localPhotos[p.imageUrl];
    }
    final previousWarning = photoSyncWarning;
    await _hydrateMissingProductImages(targets: data.products);
    if (_revision != revision) {
      photoSyncWarning = previousWarning;
      throw const CloudSyncException(
        'Local records changed during download. Retry when editing is finished.',
      );
    }
    final previous = _currentData();
    final previousCart = Map<String, int>.of(_cart);
    final previousCode = syncCode;
    final previousTime = lastSyncedAt;
    _replaceData(data);
    _cart.clear();
    syncCode = code;
    lastSyncedAt = remote.updatedAt ?? DateTime.now();
    final save = _saveNow();
    final savedRevision = _revision;
    final error = await save;
    if (error != null) {
      if (_revision == savedRevision) {
        _replaceData(previous);
        _cart.addAll(previousCart);
        syncCode = previousCode;
        lastSyncedAt = previousTime;
        photoSyncWarning = previousWarning;
      }
      notifyListeners();
      throw CloudSyncException(error);
    }
    notifyListeners();
  }

  /// Restores local records and device preferences; requires a fresh login session.
  bool _restoreSnapshot(Map<String, dynamic> snapshot) {
    final data = _decodeSnapshot(snapshot);
    final version = (snapshot['version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > _dataVersion) {
      throw FormatException('Unsupported local data version: $version');
    }

    final account = snapshot['account'];
    // Existing accounts predate onboarding and should not be interrupted.
    _tutorialDismissed =
        snapshot['tutorial_dismissed'] == true ||
        (!snapshot.containsKey('tutorial_dismissed') && account is Map);
    if (account is Map && '${account['name']}'.trim().isNotEmpty) {
      _account = {'name': '${account['name']}'.trim()};
    } else {
      _account = null;
    }

    markupPercent =
        (snapshot['markup_percent'] as num?)?.toDouble() ??
        _defaultMarkupPercent;
    syncCode = snapshot['sync_code']?.toString();
    _themeChoice = ThemeChoice.fromName(snapshot['theme']);
    _language = AppLanguage.fromCode(snapshot['language']);
    final lastSyncedRaw = snapshot['last_synced_at'];
    lastSyncedAt = lastSyncedRaw == null
        ? null
        : DateTime.tryParse('$lastSyncedRaw');

    _replaceData(data);
    _cart.clear();

    // Authentication is intentionally session-only. Every fresh app launch
    // must pass the phone's system security prompt again.
    currentUserName = null;
    return version < _dataVersion;
  }

  /// Converts snapshot list entries to typed maps for model decoding.
  List<Map<String, dynamic>> _mapRows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Builds upload JSON without device settings, account, pairing, or local paths.
  /// Includes products, customers and ledgers, sales, stock additions, and markup.
  Map<String, dynamic> _cloudSnapshot() => _snapshot()
    ..remove('tutorial_dismissed')
    ..remove('theme')
    ..remove('language')
    ..remove('account')
    ..remove('sync_code')
    ..remove('last_synced_at')
    ..['products'] = products
        .map((product) => _productToRow(product)..remove('image_path'))
        .toList();

  /// Serializes records and device settings for the local JSON file.
  /// The cart and authenticated session are kept in memory only.
  Map<String, dynamic> _snapshot() => {
    'version': _dataVersion,
    'tutorial_dismissed': _tutorialDismissed,
    'theme': _themeChoice.name,
    'language': _language.code,
    'account': _account == null ? null : Map<String, dynamic>.of(_account!),
    'markup_percent': markupPercent,
    'sync_code': syncCode,
    'last_synced_at': lastSyncedAt?.toIso8601String(),
    'products': products.map(_productToRow).toList(),
    'customers': customers.map(_customerToRow).toList(),
    'sales': sales.map(_saleToRow).toList(),
    'stock_additions': stockAdditions.map(_stockAdditionToRow).toList(),
  };

  /// Restores an inventory record from snapshot JSON.
  Product _productFromRow(Map<String, dynamic> row) {
    return Product(
      id: '${row['id']}',
      name: '${row['name']}',
      category: '${row['category']}',
      price: (row['price'] as num).toDouble(),
      stock: (row['stock'] as num).toInt(),
      costPrice: (row['cost_price'] as num?)?.toDouble(),
      imagePath: row['image_path']?.toString(),
      imageUrl: row['image_url']?.toString(),
      barcode: row['barcode']?.toString() ?? '',
      lowStockThreshold: (row['low_stock_threshold'] as num?)?.toInt() ?? 5,
      isArchived: row['is_archived'] == true,
    );
  }

  /// Restores a customer and nested ledger entries from snapshot JSON.
  Customer _customerFromRow(Map<String, dynamic> row) {
    return Customer(
      id: '${row['id']}',
      name: '${row['name']}',
      phone: row['phone']?.toString() ?? '',
      ledger: _mapRows(row['ledger']).map(_ledgerFromRow).toList(),
    );
  }

  /// Restores a historical sale and saved items from snapshot JSON.
  SaleRecord _saleFromRow(Map<String, dynamic> row) {
    return SaleRecord(
      id: '${row['id']}',
      createdAt: DateTime.parse('${row['created_at']}'),
      items: _mapRows(row['items']).map(_saleItemFromRow).toList(),
      total: (row['total'] as num).toDouble(),
      paymentType: row['payment_type'] == 'utang'
          ? PaymentType.utang
          : PaymentType.cash,
      amountReceived: (row['amount_received'] as num).toDouble(),
      change: (row['change_amount'] as num).toDouble(),
      customerId: row['customer_id']?.toString(),
    );
  }

  /// Restores product details and prices captured at the time of sale.
  SaleItem _saleItemFromRow(Map<String, dynamic> row) {
    return SaleItem(
      productId: '${row['product_id']}',
      productName: '${row['product_name']}',
      quantity: (row['quantity'] as num).toInt(),
      unitPrice: (row['unit_price'] as num).toDouble(),
      unitCost: (row['unit_cost'] as num?)?.toDouble(),
    );
  }

  /// Restores a stock-in audit record from snapshot JSON.
  StockAddition _stockAdditionFromRow(Map<String, dynamic> row) {
    return StockAddition(
      id: '${row['id']}',
      productId: '${row['product_id']}',
      productName: '${row['product_name']}',
      quantity: (row['quantity'] as num).toInt(),
      createdAt: DateTime.parse('${row['created_at']}'),
      addedBy: row['added_by']?.toString() ?? 'Unknown user',
      note: row['note']?.toString() ?? '',
    );
  }

  /// Restores a customer credit or repayment entry from snapshot JSON.
  LedgerEntry _ledgerFromRow(Map<String, dynamic> row) {
    return LedgerEntry(
      id: '${row['id']}',
      createdAt: DateTime.parse('${row['created_at']}'),
      type: row['entry_type'] == 'payment'
          ? LedgerEntryType.payment
          : LedgerEntryType.credit,
      amount: (row['amount'] as num).toDouble(),
      note: '${row['note']}',
      saleId: row['sale_id']?.toString(),
    );
  }

  /// Serializes inventory fields and photo references for snapshots.
  Map<String, dynamic> _productToRow(Product product) => {
    'id': product.id,
    'name': product.name,
    'category': product.category,
    'price': product.price,
    'stock': product.stock,
    'cost_price': product.costPrice,
    'image_path': product.imagePath,
    'image_url': product.imageUrl,
    'barcode': product.barcode,
    'low_stock_threshold': product.lowStockThreshold,
    'is_archived': product.isArchived,
  };

  /// Serializes customer contact details and ledger entries for snapshots.
  Map<String, dynamic> _customerToRow(Customer customer) => {
    'id': customer.id,
    'name': customer.name,
    'phone': customer.phone,
    'ledger': customer.ledger.map(_ledgerToRow).toList(),
  };

  /// Serializes a credit or repayment and its optional sale reference.
  Map<String, dynamic> _ledgerToRow(LedgerEntry entry) => {
    'id': entry.id,
    'created_at': entry.createdAt.toIso8601String(),
    'entry_type': entry.type == LedgerEntryType.payment ? 'payment' : 'credit',
    'amount': entry.amount,
    'note': entry.note,
    'sale_id': entry.saleId,
  };

  /// Serializes historical items, totals, payment, and customer reference.
  Map<String, dynamic> _saleToRow(SaleRecord sale) => {
    'id': sale.id,
    'created_at': sale.createdAt.toIso8601String(),
    'items': sale.items.map(_saleItemToRow).toList(),
    'total': sale.total,
    'payment_type': sale.paymentType == PaymentType.utang ? 'utang' : 'cash',
    'amount_received': sale.amountReceived,
    'change_amount': sale.change,
    'customer_id': sale.customerId,
  };

  /// Serializes a stock-in record and source note for snapshots.
  Map<String, dynamic> _stockAdditionToRow(StockAddition addition) => {
    'id': addition.id,
    'product_id': addition.productId,
    'product_name': addition.productName,
    'quantity': addition.quantity,
    'created_at': addition.createdAt.toIso8601String(),
    'added_by': addition.addedBy,
    'note': addition.note,
  };

  /// Serializes quantities and prices preserved in a historical sale item.
  Map<String, dynamic> _saleItemToRow(SaleItem item) => {
    'product_id': item.productId,
    'product_name': item.productName,
    'quantity': item.quantity,
    'unit_price': item.unitPrice,
    'unit_cost': item.unitCost,
  };

  /// Starts a local save without waiting; checkout and payment can await its result.
  void _queueSave() {
    _lastQueuedSave = _saveNow();
    unawaited(_lastQueuedSave);
  }

  /// Captures a snapshot and queues its disk write after earlier saves.
  /// Returns save errors to the caller; does not upload store records.
  Future<String?> _saveNow() {
    _revision++;
    if (_loadFailed) {
      return Future.value(
        storageError ?? 'Resolve the local data loading error before saving.',
      );
    }
    if (storage == null) return Future.value(null);
    // Capture the state for this operation, not whichever state exists later.
    final snapshot = _snapshot();
    final save = _persistenceQueue.then<String?>((_) async {
      String? errorMessage;
      try {
        await storage!.saveSnapshot(snapshot);
        storageError = null;
      } catch (error) {
        errorMessage = 'Local data could not be saved: $error';
        storageError = errorMessage;
      }
      notifyListeners();
      return errorMessage;
    });
    _persistenceQueue = save.then<void>((_) {});
    return save;
  }

  /// Creates a numeric ID greater than the supplied IDs and the current timestamp.
  String _nextId(Iterable<String> ids) {
    var greatest = DateTime.now().microsecondsSinceEpoch - 1;
    for (final id in ids) {
      final number = int.tryParse(id) ?? 0;
      if (number > greatest) greatest = number;
    }
    return '${greatest + 1}';
  }
}
