import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
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

  String? currentUserName;
  String? storageError;
  bool isLoading = false;
  Map<String, dynamic>? _account;
  double markupPercent;
  ThemeChoice _themeChoice = ThemeChoice.defaultTheme;
  ThemeChoice get themeChoice => _themeChoice;

  // Cloud sync state, persisted locally so the pairing survives app
  // restarts without needing to sync again.
  String? syncCode;
  DateTime? lastSyncedAt;
  String? photoSyncWarning;

  bool get isAuthenticated => currentUserName != null;
  bool get hasLocalAccount => _account != null;
  String? get registeredOwnerName =>
      _account == null ? null : '${_account!['name']}';
  bool get isLocalStorageEnabled => storage != null;
  bool get isCloudSyncAvailable => cloudSync != null;
  bool get isImageSyncAvailable => imageSync != null;
  Future<void> get persistenceSettled => _persistenceQueue;

  @override
  void dispose() {
    imageSync?.dispose();
    super.dispose();
  }

  List<Product> get activeProducts =>
      products.where((product) => !product.isArchived).toList();

  List<StockAddition> stockAdditionsFor(Product product) => stockAdditions
      .where((addition) => addition.productId == product.id)
      .toList();

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

  double get cartTotal =>
      cartLines.fold(0, (total, line) => total + line.subtotal);

  double get totalOutstanding =>
      customers.fold(0, (total, customer) => total + customer.balance);

  /// Suggested selling price for a given cost price, using the current
  /// markup percentage (cost + markup%).
  double suggestedSellingPrice(double costPrice) =>
      costPrice * (1 + markupPercent / 100);

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
      await _hydrateMissingProductImages();
      storageError = null;
    } catch (error) {
      storageError = 'Local data could not be loaded: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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

  Future<String?> openSecureSession(String name) async {
    final validation = validateOwnerName(name);
    if (validation != null) return validation;
    final normalized = name.trim();
    _account ??= {'name': normalized};
    currentUserName = '${_account!['name']}';
    notifyListeners();
    return _saveNow();
  }

  Future<String?> renameOwner(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return 'Enter a store name.';
    if (_account == null) return 'No store is registered on this phone yet.';
    _account!['name'] = normalized;
    notifyListeners();
    return _saveNow();
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

  Future<void> logout() async {
    currentUserName = null;
    _cart.clear();
    notifyListeners();
  }

  void addToCart(Product product) {
    if (product.isArchived || !products.contains(product)) return;
    final current = _cart[product.id] ?? 0;
    if (current >= product.stock) return;
    _cart[product.id] = current + 1;
    notifyListeners();
  }

  void removeOneFromCart(Product product) {
    final current = _cart[product.id] ?? 0;
    if (current <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current - 1;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.remove(product.id);
    notifyListeners();
  }

  Product? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    for (final product in activeProducts) {
      if (product.barcode == normalized) return product;
    }
    return null;
  }

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
        barcode: barcode.trim(),
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
        ..barcode = barcode.trim()
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

    final addition = StockAddition(
      id: _nextId(stockAdditions.map((entry) => entry.id)),
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      createdAt: DateTime.now(),
      addedBy: currentUserName ?? 'Unknown user',
      note: normalizedNote,
    );
    product.stock += quantity;
    stockAdditions.insert(0, addition);
    notifyListeners();
    _queueSave();
    return addition;
  }

  void toggleArchive(Product product) {
    product.isArchived = !product.isArchived;
    _cart.remove(product.id);
    notifyListeners();
    _queueSave();
  }

  void deleteProduct(Product product) {
    _cart.remove(product.id);
    products.removeWhere((item) => item.id == product.id);
    // Sales and credit ledgers keep their own saved product details.
    notifyListeners();
    _queueSave();
  }

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
  /// A replaced or removed photo also has its old cloud copy deleted
  /// (best effort).
  Future<ImportedProductImage> importProductImage(
    String? sourcePath, {
    String? previousPath,
    String? previousUrl,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      await storage?.deleteProductImage(previousPath);
      await _deleteRemoteImage(previousUrl);
      return const ImportedProductImage(path: null, url: null);
    }
    if (sourcePath == previousPath || storage == null) {
      final url = previousUrl ?? await _uploadImageIfLinked(sourcePath);
      return ImportedProductImage(path: sourcePath, url: url);
    }
    final imported = await storage!.importProductImage(sourcePath);
    await storage!.deleteProductImage(previousPath);
    await _deleteRemoteImage(previousUrl);
    final uploadedUrl = await _uploadImageIfLinked(imported);
    return ImportedProductImage(path: imported, url: uploadedUrl);
  }

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

  Future<void> _deleteRemoteImage(String? reference) async {
    final sync = imageSync;
    if (sync == null || reference == null || reference.isEmpty) return;
    try {
      await sync.deleteImage(reference);
    } catch (_) {
      // Best effort: an orphaned cloud file is harmless.
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
    for (final product in products) {
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

  String? recordPayment(Customer customer, double amount) {
    if (amount <= 0) return 'Enter a payment greater than zero.';
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

  SaleRecord completeSale({
    required PaymentType paymentType,
    double amountReceived = 0,
    Customer? customer,
  }) {
    if (_cart.isEmpty) throw StateError('The cart is empty.');
    if (paymentType == PaymentType.cash && amountReceived < cartTotal) {
      throw StateError('The cash amount is insufficient.');
    }
    if (paymentType == PaymentType.utang && customer == null) {
      throw StateError('Select a customer for an utang sale.');
    }

    final total = cartTotal;
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
      change: paymentType == PaymentType.cash ? amountReceived - total : 0,
      customerId: customer?.id,
    );

    for (final line in cartLines) {
      line.product.stock -= line.quantity;
    }
    sales.insert(0, sale);

    if (customer != null) {
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
  // Cloud sync (Supabase). All of these are manual, triggered only from
  // the Sync button in Settings — nothing here runs automatically, and
  // the app works fully offline whether or not any of this is ever used.
  // ---------------------------------------------------------------------

  /// Creates a brand-new cloud store from this phone's current data and
  /// returns the sync code other phones can use to join it.
  Future<CloudSyncResult> startCloudSync() async {
    final cloud = cloudSync;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    try {
      final code = await cloud.createSyncCode(_cloudSnapshot());
      syncCode = code;
      lastSyncedAt = DateTime.now();
      notifyListeners();
      await _saveNow();
      // Creating the store first grants access to its private photo folder.
      return await pushToCloud();
    } catch (error) {
      return CloudSyncResult.failure('Could not start cloud sync: $error');
    }
  }

  /// Joins an existing cloud store using a code from another phone,
  /// replacing this phone's local data with the cloud copy.
  Future<CloudSyncResult> joinCloudSync(String code) async {
    final cloud = cloudSync;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const CloudSyncResult.failure('Enter a sync code.');
    }
    try {
      final remote = await cloud.downloadSnapshot(normalized, join: true);
      if (remote == null) {
        return const CloudSyncResult.failure(
          'No store was found for that sync code.',
        );
      }
      _applyCloudSnapshot(remote.data);
      await _hydrateMissingProductImages();
      syncCode = normalized;
      lastSyncedAt = remote.updatedAt ?? DateTime.now();
      notifyListeners();
      await _saveNow();
      return CloudSyncResult.success(normalized, warning: photoSyncWarning);
    } catch (error) {
      return CloudSyncResult.failure('Could not join cloud sync: $error');
    }
  }

  /// Pushes this phone's current data to the cloud, overwriting it.
  Future<CloudSyncResult> pushToCloud() async {
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
      await _saveNow();
      return CloudSyncResult.success(code, warning: photoSyncWarning);
    } catch (error) {
      return CloudSyncResult.failure('Could not upload to cloud: $error');
    }
  }

  /// Pulls the latest cloud data down, overwriting this phone's data.
  Future<CloudSyncResult> pullFromCloud() async {
    final cloud = cloudSync;
    final code = syncCode;
    if (cloud == null) {
      return const CloudSyncResult.failure('Cloud sync is not available.');
    }
    if (code == null) {
      return const CloudSyncResult.failure('Set up sync first.');
    }
    try {
      final remote = await cloud.downloadSnapshot(code);
      if (remote == null) {
        return const CloudSyncResult.failure(
          'No cloud data was found for this sync code.',
        );
      }
      _applyCloudSnapshot(remote.data);
      await _hydrateMissingProductImages();
      lastSyncedAt = remote.updatedAt ?? DateTime.now();
      notifyListeners();
      await _saveNow();
      return CloudSyncResult.success(code, warning: photoSyncWarning);
    } catch (error) {
      return CloudSyncResult.failure('Could not download from cloud: $error');
    }
  }

  /// Clears this phone's store and photo cache. The cloud store and the
  /// device's owner login remain available so the code can be joined again.
  Future<String?> leaveCloudSync() async {
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
    if (error != null) return error;
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
  Future<void> _hydrateMissingProductImages() async {
    photoSyncWarning = null;
    final sync = imageSync;
    final localStorage = storage;
    if (sync == null || localStorage == null) return;
    var failed = 0;
    Object? firstError;
    for (final product in products) {
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

  /// Applies a downloaded cloud snapshot on top of this phone's data.
  /// Unlike [_restoreSnapshot] (used for local-disk loading at launch),
  /// this never touches the current login session or account name, since
  /// those are meant to stay tied to this specific phone.
  void _applyCloudSnapshot(Map<String, dynamic> snapshot) {
    final localPhotos = <String, String>{
      for (final product in products)
        if (product.imageUrl != null && product.imagePath != null)
          product.imageUrl!: product.imagePath!,
    };
    products
      ..clear()
      ..addAll(
        _mapRows(snapshot['products']).map((row) {
          final product = _productFromRow(row);
          // A path from another phone is never a local photo cache.
          product.imagePath = localPhotos[product.imageUrl];
          return product;
        }),
      );
    customers
      ..clear()
      ..addAll(_mapRows(snapshot['customers']).map(_customerFromRow));
    sales
      ..clear()
      ..addAll(_mapRows(snapshot['sales']).map(_saleFromRow));
    stockAdditions
      ..clear()
      ..addAll(
        _mapRows(snapshot['stock_additions']).map(_stockAdditionFromRow),
      );
    final markup = snapshot['markup_percent'];
    if (markup is num) markupPercent = markup.toDouble();
    // The cart references product identities that may no longer match
    // after a full data swap, so it's safest to clear it.
    _cart.clear();
  }

  bool _restoreSnapshot(Map<String, dynamic> snapshot) {
    final version = (snapshot['version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > _dataVersion) {
      throw FormatException('Unsupported local data version: $version');
    }

    final account = snapshot['account'];
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
    final lastSyncedRaw = snapshot['last_synced_at'];
    lastSyncedAt = lastSyncedRaw == null
        ? null
        : DateTime.tryParse('$lastSyncedRaw');

    products
      ..clear()
      ..addAll(_mapRows(snapshot['products']).map(_productFromRow));
    customers
      ..clear()
      ..addAll(_mapRows(snapshot['customers']).map(_customerFromRow));
    sales
      ..clear()
      ..addAll(_mapRows(snapshot['sales']).map(_saleFromRow));
    stockAdditions
      ..clear()
      ..addAll(
        _mapRows(snapshot['stock_additions']).map(_stockAdditionFromRow),
      );

    // Authentication is intentionally session-only. Every fresh app launch
    // must pass the phone's system security prompt again.
    currentUserName = null;
    return version < _dataVersion;
  }

  List<Map<String, dynamic>> _mapRows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Map<String, dynamic> _cloudSnapshot() => _snapshot()
    ..remove('theme')
    ..remove('account')
    ..remove('sync_code')
    ..remove('last_synced_at')
    ..['products'] = products
        .map((product) => _productToRow(product)..remove('image_path'))
        .toList();

  Map<String, dynamic> _snapshot() => {
    'version': _dataVersion,
    'theme': _themeChoice.name,
    'account': _account,
    'markup_percent': markupPercent,
    'sync_code': syncCode,
    'last_synced_at': lastSyncedAt?.toIso8601String(),
    'products': products.map(_productToRow).toList(),
    'customers': customers.map(_customerToRow).toList(),
    'sales': sales.map(_saleToRow).toList(),
    'stock_additions': stockAdditions.map(_stockAdditionToRow).toList(),
  };

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

  Customer _customerFromRow(Map<String, dynamic> row) {
    return Customer(
      id: '${row['id']}',
      name: '${row['name']}',
      phone: row['phone']?.toString() ?? '',
      ledger: _mapRows(row['ledger']).map(_ledgerFromRow).toList(),
    );
  }

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

  SaleItem _saleItemFromRow(Map<String, dynamic> row) {
    return SaleItem(
      productId: '${row['product_id']}',
      productName: '${row['product_name']}',
      quantity: (row['quantity'] as num).toInt(),
      unitPrice: (row['unit_price'] as num).toDouble(),
      unitCost: (row['unit_cost'] as num?)?.toDouble(),
    );
  }

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

  Map<String, dynamic> _customerToRow(Customer customer) => {
    'id': customer.id,
    'name': customer.name,
    'phone': customer.phone,
    'ledger': customer.ledger.map(_ledgerToRow).toList(),
  };

  Map<String, dynamic> _ledgerToRow(LedgerEntry entry) => {
    'id': entry.id,
    'created_at': entry.createdAt.toIso8601String(),
    'entry_type': entry.type == LedgerEntryType.payment ? 'payment' : 'credit',
    'amount': entry.amount,
    'note': entry.note,
    'sale_id': entry.saleId,
  };

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

  Map<String, dynamic> _stockAdditionToRow(StockAddition addition) => {
    'id': addition.id,
    'product_id': addition.productId,
    'product_name': addition.productName,
    'quantity': addition.quantity,
    'created_at': addition.createdAt.toIso8601String(),
    'added_by': addition.addedBy,
    'note': addition.note,
  };

  Map<String, dynamic> _saleItemToRow(SaleItem item) => {
    'product_id': item.productId,
    'product_name': item.productName,
    'quantity': item.quantity,
    'unit_price': item.unitPrice,
    'unit_cost': item.unitCost,
  };

  void _queueSave() {
    if (storage == null) return;
    _persistenceQueue = _persistenceQueue.then((_) async {
      try {
        await storage!.saveSnapshot(_snapshot());
        storageError = null;
      } catch (error) {
        storageError = 'Local data could not be saved: $error';
      }
      notifyListeners();
    });
    unawaited(_persistenceQueue);
  }

  Future<String?> _saveNow() async {
    if (storage == null) return null;
    _queueSave();
    await _persistenceQueue;
    return storageError;
  }

  String _nextId(Iterable<String> ids) {
    var greatest = DateTime.now().microsecondsSinceEpoch - 1;
    for (final id in ids) {
      final number = int.tryParse(id) ?? 0;
      if (number > greatest) greatest = number;
    }
    return '${greatest + 1}';
  }
}
